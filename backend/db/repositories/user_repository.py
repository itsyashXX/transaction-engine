from db.connection import MongoManager
from common.security import hash_password

class UserRepository:
    @classmethod
    def get_collection(cls):
        return MongoManager.get_db().users

    @classmethod
    def find_by_username(cls, username: str):
        return cls.get_collection().find_one({"username": username})

    @classmethod
    def create_user(cls, username: str, password: str, role: str = "USER"):
        if cls.find_by_username(username):
            raise ValueError("USERNAME_EXISTS")
            
        doc = {
            "username": username,
            "password_hash": hash_password(password),
            "role": role,
            "status": "ACTIVE",
            "created_at": "TODO_UTC_ISO"
        }
        res = cls.get_collection().insert_one(doc)
        return str(res.inserted_id)
