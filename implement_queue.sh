#!/bin/bash
set -e

echo "Creating queue and idempotency repositories..."
cat << 'IREP' > backend/db/repositories/idempotency_repository.py
from db.connection import MongoManager
from pymongo import ReturnDocument

class IdempotencyRepository:
    @classmethod
    def get_collection(cls):
        return MongoManager.get_db().idempotency_keys

    @classmethod
    def save_idempotency_key(cls, key: str, payload_fingerprint: str, transaction_id: str):
        # Uses MongoDB Unique Index on 'key' to prevent concurrent duplicates (Rule 55, 56)
        try:
            doc = {
                "key": key,
                "payload_fingerprint": payload_fingerprint,
                "transaction_id": transaction_id,
                "status": "PROCESSING",
                "created_at": "TODO_UTC_ISO"
            }
            cls.get_collection().insert_one(doc)
            return True, doc
        except Exception as e:
            # Check for DuplicateKeyError (assuming PyMongo mapping)
            if "duplicate key error" in str(e).lower():
                return False, cls.get_collection().find_one({"key": key})
            raise e
IREP

cat << 'QREP' > backend/db/repositories/queue_repository.py
from db.connection import MongoManager
from pymongo import ReturnDocument
import datetime
import os

class QueueRepository:
    @classmethod
    def get_collection(cls):
        return MongoManager.get_db().queue_items

    @classmethod
    def enqueue(cls, transaction_id: str):
        doc = {
            "transaction_id": transaction_id,
            "status": "QUEUED",
            "created_at": datetime.datetime.utcnow().isoformat(),
            "worker_id": None,
            "lease_until": None,
            "attempt_count": 0
        }
        cls.get_collection().insert_one(doc)
        return doc

    @classmethod
    def claim_next(cls, worker_id: str):
        # Rule 62: ATOMIC WORKER CLAIM
        # Find oldest QUEUED item, or stale lease
        now = datetime.datetime.utcnow()
        lease_seconds = int(os.getenv("WORKER_LEASE_SECONDS", 30))
        lease_until = (now + datetime.timedelta(seconds=lease_seconds)).isoformat()
        
        query = {
            "$or": [
                {"status": "QUEUED"},
                {"status": "PROCESSING", "lease_until": {"$lt": now.isoformat()}} # Rule 64: Stale Recovery
            ]
        }
        
        update = {
            "$set": {
                "status": "PROCESSING",
                "worker_id": worker_id,
                "lease_until": lease_until
            },
            "$inc": {"attempt_count": 1}
        }
        
        # Sort by created_at to prefer oldest
        return cls.get_collection().find_one_and_update(
            query,
            update,
            sort=[("created_at", 1)],
            return_document=ReturnDocument.AFTER
        )
        
    @classmethod
    def mark_completed(cls, transaction_id: str):
        cls.get_collection().update_one(
            {"transaction_id": transaction_id},
            {"$set": {"status": "COMPLETED"}}
        )
        
    @classmethod
    def mark_failed(cls, transaction_id: str):
        cls.get_collection().update_one(
            {"transaction_id": transaction_id},
            {"$set": {"status": "FAILED"}}
        )
QREP

echo "Creating workers..."
cat << 'LMAN' > backend/workers/lease_manager.py
from db.repositories.queue_repository import QueueRepository

class LeaseManager:
    def __init__(self, worker_id: str):
        self.worker_id = worker_id

    def claim_transaction(self):
        # Atomically pulls next transaction
        return QueueRepository.claim_next(self.worker_id)
        
    def release_transaction(self, transaction_id: str, success: bool):
        if success:
            QueueRepository.mark_completed(transaction_id)
        else:
            QueueRepository.mark_failed(transaction_id)
LMAN

cat << 'PROC' > backend/workers/processor.py
import time
import os
import uuid
from workers.lease_manager import LeaseManager
from services.transaction_service import TransactionService

class TransactionProcessor:
    def __init__(self):
        self.worker_id = f"worker-{uuid.uuid4().hex[:8]}"
        self.lease_manager = LeaseManager(self.worker_id)
        self.poll_interval = int(os.getenv("QUEUE_POLL_INTERVAL", 2))

    def run(self):
        print(f"Worker {self.worker_id} started. Polling queue...")
        while True:
            item = self.lease_manager.claim_transaction()
            if not item:
                time.sleep(self.poll_interval)
                continue
                
            print(f"[{self.worker_id}] Claimed transaction {item['transaction_id']}")
            
            # NOTE: Transaction execution logic needs to be decoupled from HTTP sync path
            # In a real async path, the API puts to queue, worker executes atomic_add/subtract.
            # For demonstration, we simply mark it success here for Phase 10.
            try:
                # Simulate processing delay
                time.sleep(1)
                
                # Rule 64: Process safely
                self.lease_manager.release_transaction(item['transaction_id'], success=True)
                print(f"[{self.worker_id}] Completed {item['transaction_id']}")
            except Exception as e:
                print(f"[{self.worker_id}] Failed {item['transaction_id']}: {str(e)}")
                self.lease_manager.release_transaction(item['transaction_id'], success=False)
PROC

echo "Done."
