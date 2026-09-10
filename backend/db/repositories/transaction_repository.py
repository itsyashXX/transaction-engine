from db.connection import MongoManager
import uuid
import datetime

class TransactionRepository:
    @classmethod
    def get_collection(cls):
        return MongoManager.get_db().transactions

    @classmethod
    def create_transaction(cls, account_id: str, operation: str, amount_minor: int, idempotency_key: str):
        doc = {
            "transaction_id": str(uuid.uuid4()),
            "account_id": account_id,
            "operation": operation,
            "amount_minor": amount_minor,
            "status": "QUEUED",
            "idempotency_key": idempotency_key,
            "created_at": datetime.datetime.utcnow().isoformat(),
            "version": 1
        }
        cls.get_collection().insert_one(doc)
        return doc

    @classmethod
    def update_status(cls, transaction_id: str, new_status: str, failure_reason: str = None):
        update_doc = {"status": new_status, "$inc": {"version": 1}}
        if failure_reason:
            update_doc["failure_reason"] = failure_reason
            
        return cls.get_collection().find_one_and_update(
            {"transaction_id": transaction_id},
            {"$set": update_doc},
            return_document=True
        )
