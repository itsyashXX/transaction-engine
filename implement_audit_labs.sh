#!/bin/bash
set -e

echo "Creating Audit Event Repository..."
cat << 'EREP' > backend/db/repositories/event_repository.py
from db.connection import MongoManager
import datetime
import uuid

class EventRepository:
    @classmethod
    def get_collection(cls):
        return MongoManager.get_db().events

    @classmethod
    def append_event(cls, transaction_id: str, event_type: str, message: str, metadata: dict = None):
        # Rule 67 & 69: Append-oriented real event history. No updates allowed.
        doc = {
            "event_id": str(uuid.uuid4()),
            "transaction_id": transaction_id,
            "event_type": event_type,
            "message": message,
            "metadata": metadata or {},
            "timestamp": datetime.datetime.utcnow().isoformat()
        }
        cls.get_collection().insert_one(doc)
        return doc
EREP

echo "Creating Event Service..."
cat << 'ESER' > backend/services/event_service.py
from db.repositories.event_repository import EventRepository

class EventService:
    @classmethod
    def log_lifecycle(cls, transaction_id: str, status: str, details: str = None):
        event_map = {
            "QUEUED": "TRANSACTION_QUEUED",
            "PROCESSING": "PROCESSING_STARTED",
            "COMPLETED": "TRANSACTION_COMPLETED",
            "FAILED": "TRANSACTION_FAILED",
            "CONFLICT": "CONCURRENCY_CONFLICT",
            "DUPLICATE": "DUPLICATE_DETECTED"
        }
        
        event_type = event_map.get(status, "UNKNOWN_EVENT")
        metadata = {"details": details} if details else {}
        
        EventRepository.append_event(transaction_id, event_type, f"Transaction transitioned to {status}", metadata)
ESER

echo "Creating Concurrency Race Lab (Rule 48)..."
mkdir -p backend/tests/concurrency
cat << 'RLAB' > backend/tests/concurrency/race_lab.py
import sys
import os
import uuid
import concurrent.futures

# Setup Python Path for standalone execution
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from db.connection import MongoManager
from db.repositories.account_repository import AccountRepository
from db.repositories.event_repository import EventRepository

def race_worker(account_id, amount):
    try:
        # Rule 42 & 143: Atomic subtraction test
        res = AccountRepository.atomic_subtract(account_id, amount)
        return True, "SUCCESS"
    except ValueError as e:
        return False, str(e)
    except Exception as e:
        return False, f"ERROR: {str(e)}"

def run_lab():
    print("=======================================")
    print("      CONCURRENCY RACE LAB (Rule 48)   ")
    print("=======================================")
    
    account_id = f"lab-account-{uuid.uuid4().hex[:8]}"
    
    print(f"\n1. Initializing lab account '{account_id}' with ₹1,000 (100,000 minor units).")
    AccountRepository.ensure_account(account_id)
    AccountRepository.atomic_add(account_id, 100000)
    
    print("\n2. Firing two concurrent requests to SUBTRACT ₹800 (Total ₹1,600 requested)...")
    results = []
    
    # Real parallel execution via ThreadPoolExecutor (Rule 49)
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        f1 = executor.submit(race_worker, account_id, 80000)
        f2 = executor.submit(race_worker, account_id, 80000)
        results.append(f1.result())
        results.append(f2.result())
        
    print(f"\nExecution Results: {results}")
    
    print("\n3. Verifying Database Invariants (Rule 53 & 54)...")
    db = MongoManager.get_db()
    final_acc = db.accounts.find_one({"account_id": account_id})
    final_balance = final_acc["balance_minor"]
    
    print(f"-> Final Balance: {final_balance} paise (Expected: 20000)")
    
    if final_balance >= 0:
        print("-> INVARIANT MAINTAINED: Balance did not drop below zero!")
        if final_balance == 20000:
            print("-> RACE PROTECTION SUCCESS: Exactly one operation was accepted, one was rejected.")
    else:
        print("-> INVARIANT VIOLATED: Negative balance detected! Race condition occurred.")

if __name__ == '__main__':
    run_lab()
RLAB

echo "Done."
