#!/bin/bash
set -e

echo "Creating common security utilities..."
cat << 'SEC' > backend/common/security.py
import os
import jwt
import datetime
from django.contrib.auth.hashers import make_password, check_password

SECRET_KEY = os.getenv('JWT_SECRET', 'fallback-secret-key-do-not-use-in-prod')

def hash_password(password: str) -> str:
    return make_password(password)

def verify_password(password: str, hashed: str) -> bool:
    return check_password(password, hashed)

def generate_token(user_id: str, role: str) -> str:
    payload = {
        'user_id': str(user_id),
        'role': role,
        'exp': datetime.datetime.utcnow() + datetime.timedelta(seconds=int(os.getenv('JWT_ACCESS_TOKEN_EXPIRES', 3600))),
        'iat': datetime.datetime.utcnow()
    }
    return jwt.encode(payload, SECRET_KEY, algorithm='HS256')

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
    except jwt.ExpiredSignatureError:
        raise ValueError("TOKEN_EXPIRED")
    except jwt.InvalidTokenError:
        raise ValueError("AUTH_INVALID")
SEC

echo "Creating repositories..."
cat << 'UREP' > backend/db/repositories/user_repository.py
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
UREP

cat << 'AREP' > backend/db/repositories/account_repository.py
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
AREP

cat << 'TREP' > backend/db/repositories/transaction_repository.py
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
TREP

echo "Creating services..."
cat << 'ASER' > backend/services/authentication_service.py
from db.repositories.user_repository import UserRepository
from common.security import verify_password, generate_token

class AuthenticationService:
    @classmethod
    def login(cls, username: str, password: str):
        user = UserRepository.find_by_username(username)
        if not user or not verify_password(password, user['password_hash']):
            raise ValueError("AUTH_INVALID")
            
        if user['status'] != 'ACTIVE':
            raise ValueError("FORBIDDEN")
            
        token = generate_token(str(user['_id']), user['role'])
        return {
            "token": token,
            "role": user['role'],
            "username": user['username']
        }
ASER

cat << 'TSER' > backend/services/transaction_service.py
from db.repositories.account_repository import AccountRepository
from db.repositories.transaction_repository import TransactionRepository

class TransactionService:
    @classmethod
    def execute_transaction_sync(cls, account_id: str, operation: str, amount_minor: int, idempotency_key: str):
        # Explicit synchronous execution for Phase 8 demonstration (Pre-Queue Phase)
        if operation not in ['ADD', 'SUBTRACT']:
            raise ValueError("INVALID_OPERATION")
            
        if amount_minor <= 0:
            raise ValueError("INVALID_AMOUNT")
            
        # 1. Create Transaction (QUEUED)
        txn = TransactionRepository.create_transaction(account_id, operation, amount_minor, idempotency_key)
        
        # 2. Update to PROCESSING
        TransactionRepository.update_status(txn['transaction_id'], 'PROCESSING')
        
        # 3. Atomic execution
        try:
            if operation == 'ADD':
                AccountRepository.atomic_add(account_id, amount_minor)
            elif operation == 'SUBTRACT':
                AccountRepository.atomic_subtract(account_id, amount_minor)
                
            # 4. Mark COMPLETED
            return TransactionRepository.update_status(txn['transaction_id'], 'COMPLETED')
            
        except ValueError as e:
            # 5. Mark FAILED or CONFLICT
            reason = str(e)
            status = 'CONFLICT' if reason == 'INSUFFICIENT_BALANCE_OR_NOT_FOUND' else 'FAILED'
            return TransactionRepository.update_status(txn['transaction_id'], status, failure_reason=reason)
        except Exception as e:
            TransactionRepository.update_status(txn['transaction_id'], 'FAILED', failure_reason="SYSTEM_ERROR")
            raise
TSER

echo "Writing seeder script (Rule 19, 26)..."
cat << 'SEED' > backend/scripts/development_seed.py
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from db.connection import MongoManager
from db.repositories.user_repository import UserRepository
from db.repositories.account_repository import AccountRepository

def seed():
    print("Running Development Seed...")
    db = MongoManager.get_db()
    
    # Check if admin exists
    if not UserRepository.find_by_username("sarvesh"):
        print("Creating admin user 'sarvesh' (Rule 26)...")
        user_id = UserRepository.create_user("sarvesh", "sarvesh@suyal", "ADMIN")
        AccountRepository.ensure_account(user_id)
    else:
        print("Admin user already exists. Skipping.")
        
    # Check if demo user exists
    if not UserRepository.find_by_username("demo_user"):
        print("Creating demo user 'demo_user'...")
        user_id = UserRepository.create_user("demo_user", "password123", "USER")
        AccountRepository.ensure_account(user_id)
        # Give them some initial demo balance
        AccountRepository.atomic_add(user_id, 100000) # 1000 INR
    else:
        print("Demo user already exists. Skipping.")
        
    print("Seed complete. Preserved existing data.")

if __name__ == '__main__':
    seed()
SEED

echo "Done."
