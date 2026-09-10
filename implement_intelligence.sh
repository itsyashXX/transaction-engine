#!/bin/bash
set -e

echo "Creating Intelligence Layer directories..."
mkdir -p backend/intelligence

echo "Writing Metrics Engine (Phase 21)..."
cat << 'MET' > backend/intelligence/metrics.py
from db.connection import MongoManager

class MetricsEngine:
    @classmethod
    def get_transaction_stats(cls):
        db = MongoManager.get_db()
        pipeline = [
            {"$group": {"_id": "$status", "count": {"$sum": 1}}}
        ]
        results = list(db.transactions.aggregate(pipeline))
        # Returns format like: {"COMPLETED": 12, "FAILED": 1, "QUEUED": 5}
        stats = {r['_id']: r['count'] for r in results}
        return stats
MET

echo "Writing AI Anomaly Detector (Phase 22)..."
cat << 'ANO' > backend/intelligence/anomaly_detector.py
from db.connection import MongoManager
import datetime
import os

class AnomalyDetector:
    # Rule 89: Velocity Spikes (e.g., 5 transactions in 10 seconds)
    VELOCITY_THRESHOLD = int(os.getenv("ANOMALY_VELOCITY_THRESHOLD", 5))
    VELOCITY_WINDOW_SECONDS = int(os.getenv("ANOMALY_WINDOW_SECONDS", 10))

    @classmethod
    def check_velocity(cls, account_id: str) -> bool:
        """
        Returns True if anomalous velocity is detected.
        A real ML pipeline would feature-encode this, but we use hard heuristics for the lab baseline.
        """
        db = MongoManager.get_db()
        time_threshold = datetime.datetime.utcnow() - datetime.timedelta(seconds=cls.VELOCITY_WINDOW_SECONDS)
        
        # Fast indexed count on recent transactions
        recent_tx_count = db.transactions.count_documents({
            "account_id": account_id,
            "created_at": {"$gte": time_threshold.isoformat()}
        })
        
        if recent_tx_count >= cls.VELOCITY_THRESHOLD:
            cls._log_anomaly(account_id, "HIGH_VELOCITY", f"{recent_tx_count} transactions in {cls.VELOCITY_WINDOW_SECONDS}s")
            return True
            
        return False
        
    @classmethod
    def _log_anomaly(cls, account_id: str, anomaly_type: str, details: str):
        db = MongoManager.get_db()
        db.anomalies.insert_one({
            "account_id": account_id,
            "type": anomaly_type,
            "details": details,
            "detected_at": datetime.datetime.utcnow().isoformat(),
            "status": "REQUIRES_REVIEW",
            "resolution": None
        })
ANO

echo "Updating Transaction API to hook Anomaly Detection..."
cat << 'TVWS' > backend/apps/transactions/views.py
import json
import uuid
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from db.repositories.idempotency_repository import IdempotencyRepository
from db.repositories.queue_repository import QueueRepository
from services.event_service import EventService
from db.repositories.transaction_repository import TransactionRepository
from intelligence.anomaly_detector import AnomalyDetector

@csrf_exempt
def create_transaction(request):
    if request.method != 'POST':
        return JsonResponse({"error": "Method not allowed"}, status=405)
        
    try:
        data = json.loads(request.body)
        amount_minor = data.get('amount_minor')
        operation = data.get('operation')
        idempotency_key = data.get('idempotency_key')
        
        if not all([amount_minor, operation, idempotency_key]):
            return JsonResponse({"error": "Missing required fields"}, status=400)
            
        user_id = request.user_id
        
        # PHASE 22: AI Anomaly Detection Hook (Rule 89)
        if AnomalyDetector.check_velocity(user_id):
            return JsonResponse({"error": "FROZEN_DUE_TO_SUSPICIOUS_ACTIVITY"}, status=429)
        
        # Rule 55: Idempotency Protection
        transaction_id = str(uuid.uuid4())
        fingerprint = f"{operation}:{amount_minor}"
        
        is_new, doc = IdempotencyRepository.save_idempotency_key(idempotency_key, fingerprint, transaction_id)
        if not is_new:
            # Rule 56: Exact Duplicate
            if doc['payload_fingerprint'] == fingerprint:
                return JsonResponse({
                    "success": True, 
                    "message": "Idempotent request matched", 
                    "transaction_id": doc['transaction_id']
                }, status=200)
            # Rule 57: Conflict Duplicate
            return JsonResponse({"error": "IDEMPOTENCY_KEY_REUSE_CONFLICT"}, status=409)
            
        # Create core transaction document
        TransactionRepository.create_transaction(user_id, operation, amount_minor, idempotency_key)
            
        # Rule 59: Enqueue Transaction
        queue_item = QueueRepository.enqueue(transaction_id)
        EventService.log_lifecycle(transaction_id, "QUEUED", f"Requested {operation} for {amount_minor} minor units")
        
        return JsonResponse({
            "success": True,
            "message": "Transaction accepted and queued",
            "transaction_id": transaction_id,
            "status": "QUEUED"
        }, status=202)
        
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
TVWS

echo "Done."
