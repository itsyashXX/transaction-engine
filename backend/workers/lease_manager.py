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
