from db.connection import MongoManager
from pymongo import ReturnDocument

class AccountRepository:
    @classmethod
    def get_collection(cls):
        return MongoManager.get_db().accounts

    @classmethod
    def ensure_account(cls, account_id: str):
        return cls.get_collection().find_one_and_update(
            {"account_id": account_id},
            {"$setOnInsert": {"balance_minor": 0, "currency": "INR", "version": 1, "status": "ACTIVE"}},
            upsert=True,
            return_document=ReturnDocument.AFTER
        )

    @classmethod
    def atomic_add(cls, account_id: str, amount_minor: int):
        if amount_minor <= 0:
            raise ValueError("INVALID_AMOUNT")
            
        # Rule 41: Real backend ADD amount using MongoDB-backed state
        return cls.get_collection().find_one_and_update(
            {"account_id": account_id},
            {"$inc": {"balance_minor": amount_minor, "version": 1}},
            return_document=ReturnDocument.AFTER
        )

    @classmethod
    def atomic_subtract(cls, account_id: str, amount_minor: int):
        if amount_minor <= 0:
            raise ValueError("INVALID_AMOUNT")
            
        # Rule 42: UPDATE account ONLY IF balance >= amount then $inc balance by -amount
        result = cls.get_collection().find_one_and_update(
            {
                "account_id": account_id,
                "balance_minor": {"$gte": amount_minor}
            },
            {"$inc": {"balance_minor": -amount_minor, "version": 1}},
            return_document=ReturnDocument.AFTER
        )
        
        if not result:
            raise ValueError("INSUFFICIENT_BALANCE_OR_NOT_FOUND")
            
        return result
