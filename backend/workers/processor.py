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
