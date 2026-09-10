from db.connection import MongoManager

class MetricsEngine:
    @classmethod
    def get_transaction_stats(cls):
        db = MongoManager.get_db()
        pipeline = [
            {"$group": {"_id": "$status", "count": {"$sum": 1}}}
        ]
        results = list(db.transactions.aggregate(pipeline))
        # Returns format like: {"COMPLETED": 12, "FAILED": 1, "QUEUED": 5}
        stats = {r['_id']: r['count'] for r in results}
        return stats
