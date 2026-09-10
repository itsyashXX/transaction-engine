from db.connection import MongoManager
import datetime
import os

class AnomalyDetector:
    # Rule 89: Velocity Spikes (e.g., 5 transactions in 10 seconds)
    VELOCITY_THRESHOLD = int(os.getenv("ANOMALY_VELOCITY_THRESHOLD", 5))
    VELOCITY_WINDOW_SECONDS = int(os.getenv("ANOMALY_WINDOW_SECONDS", 10))

    @classmethod
    def check_velocity(cls, account_id: str) -> bool:
        """
        Returns True if anomalous velocity is detected.
        A real ML pipeline would feature-encode this, but we use hard heuristics for the lab baseline.
        """
        db = MongoManager.get_db()
        time_threshold = datetime.datetime.utcnow() - datetime.timedelta(seconds=cls.VELOCITY_WINDOW_SECONDS)
        
        # Fast indexed count on recent transactions
        recent_tx_count = db.transactions.count_documents({
            "account_id": account_id,
            "created_at": {"$gte": time_threshold.isoformat()}
        })
        
        if recent_tx_count >= cls.VELOCITY_THRESHOLD:
            cls._log_anomaly(account_id, "HIGH_VELOCITY", f"{recent_tx_count} transactions in {cls.VELOCITY_WINDOW_SECONDS}s")
            return True
            
        return False
        
    @classmethod
    def _log_anomaly(cls, account_id: str, anomaly_type: str, details: str):
        db = MongoManager.get_db()
        db.anomalies.insert_one({
            "account_id": account_id,
            "type": anomaly_type,
            "details": details,
            "detected_at": datetime.datetime.utcnow().isoformat(),
            "status": "REQUIRES_REVIEW",
            "resolution": None
        })
