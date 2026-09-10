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
