import os
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

class DatabaseConfig:
    URI = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
    DB_NAME = os.getenv("MONGODB_DATABASE", "transaction_engine")
    TIMEOUT = int(os.getenv("MONGODB_SERVER_SELECTION_TIMEOUT_MS", 5000))

class MongoManager:
    _client = None

    @classmethod
    def get_client(cls):
        if cls._client is None:
            # ONE authoritative MongoClient lifecycle
            cls._client = MongoClient(
                DatabaseConfig.URI,
                serverSelectionTimeoutMS=DatabaseConfig.TIMEOUT,
                connectTimeoutMS=int(os.getenv("MONGODB_CONNECT_TIMEOUT_MS", 10000)),
                socketTimeoutMS=int(os.getenv("MONGODB_SOCKET_TIMEOUT_MS", 10000)),
            )
        return cls._client

    @classmethod
    def get_db(cls):
        return cls.get_client()[DatabaseConfig.DB_NAME]

    @classmethod
    def check_health(cls):
        try:
            cls.get_client().admin.command('ping')
            return True
        except ConnectionFailure:
            return False
