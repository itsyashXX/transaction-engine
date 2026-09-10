from django.urls import path
from django.http import JsonResponse
from db.connection import MongoManager

def health_check(request):
    db_ok = MongoManager.check_health()
    return JsonResponse({
        "success": True,
        "data": {
            "status": "UP" if db_ok else "DOWN",
            "database": "CONNECTED" if db_ok else "DISCONNECTED"
        }
    }, status=200 if db_ok else 503)

urlpatterns = [
    path('api/health', health_check),
]
