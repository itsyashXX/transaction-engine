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
