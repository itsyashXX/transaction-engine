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
