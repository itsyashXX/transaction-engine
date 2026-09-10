import json
import uuid
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from db.repositories.idempotency_repository import IdempotencyRepository
from db.repositories.queue_repository import QueueRepository
from services.event_service import EventService
from db.repositories.transaction_repository import TransactionRepository

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
        
        # Rule 55: Idempotency Protection (Check before queuing)
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
            # Rule 57: Conflict Duplicate (Key reused with different payload)
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
