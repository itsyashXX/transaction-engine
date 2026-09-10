#!/bin/bash
set -e

echo "Creating middleware..."
cat << 'MID' > backend/common/middleware.py
from django.http import JsonResponse
from common.security import decode_token

class JWTAuthenticationMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Allow health check and auth login without token
        if request.path.startswith('/api/health') or request.path.startswith('/api/auth'):
            return self.get_response(request)

        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return JsonResponse({"error": "Unauthorized", "code": "NO_TOKEN"}, status=401)

        token = auth_header.split(' ')[1]
        try:
            payload = decode_token(token)
            request.user_id = payload['user_id']
            request.user_role = payload['role']
        except ValueError as e:
            return JsonResponse({"error": str(e), "code": "INVALID_TOKEN"}, status=401)
        except Exception:
            return JsonResponse({"error": "Unauthorized", "code": "INVALID_TOKEN"}, status=401)

        return self.get_response(request)
MID

echo "Updating settings to include middleware..."
cat << 'STG' > backend/config/settings/base.py
import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()
BASE_DIR = Path(__file__).resolve().parent.parent.parent
SECRET_KEY = os.getenv('JWT_SECRET', 'fallback-secret-key-do-not-use-in-prod')
DEBUG = os.getenv('DEBUG', 'True') == 'True'
ALLOWED_HOSTS = ['*']

INSTALLED_APPS = [
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'rest_framework',
    'apps.users',
    'apps.transactions',
]
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
    'common.middleware.JWTAuthenticationMiddleware',
]
ROOT_URLCONF = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
DATABASES = {} 
LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_TZ = True
STG

echo "Creating apps directories and __init__.py files..."
touch backend/apps/__init__.py
touch backend/apps/users/__init__.py
touch backend/apps/transactions/__init__.py

echo "Creating users API (Phase 17)..."
cat << 'UVWS' > backend/apps/users/views.py
import json
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from services.authentication_service import AuthenticationService

@csrf_exempt
def login_view(request):
    if request.method != 'POST':
        return JsonResponse({"error": "Method not allowed"}, status=405)
        
    try:
        data = json.loads(request.body)
        username = data.get('username')
        password = data.get('password')
        
        result = AuthenticationService.login(username, password)
        return JsonResponse({"success": True, "data": result})
    except ValueError as e:
        return JsonResponse({"success": False, "error": str(e)}, status=401)
    except Exception as e:
        return JsonResponse({"success": False, "error": "Internal server error"}, status=500)
UVWS

echo "Creating transactions API (Phase 18)..."
cat << 'TVWS' > backend/apps/transactions/views.py
import json
import uuid
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from db.repositories.idempotency_repository import IdempotencyRepository
from db.repositories.queue_repository import QueueRepository
from services.event_service import EventService
from db.repositories.transaction_repository import TransactionRepository

@csrf_exempt
def create_transaction(request):
    if request.method != 'POST':
        return JsonResponse({"error": "Method not allowed"}, status=405)
        
    try:
        data = json.loads(request.body)
        amount_minor = data.get('amount_minor')
        operation = data.get('operation')
        idempotency_key = data.get('idempotency_key')
        
        if not all([amount_minor, operation, idempotency_key]):
            return JsonResponse({"error": "Missing required fields"}, status=400)
            
        user_id = request.user_id
        
        # Rule 55: Idempotency Protection (Check before queuing)
        transaction_id = str(uuid.uuid4())
        fingerprint = f"{operation}:{amount_minor}"
        
        is_new, doc = IdempotencyRepository.save_idempotency_key(idempotency_key, fingerprint, transaction_id)
        if not is_new:
            # Rule 56: Exact Duplicate
            if doc['payload_fingerprint'] == fingerprint:
                return JsonResponse({
                    "success": True, 
                    "message": "Idempotent request matched", 
                    "transaction_id": doc['transaction_id']
                }, status=200)
            # Rule 57: Conflict Duplicate (Key reused with different payload)
            return JsonResponse({"error": "IDEMPOTENCY_KEY_REUSE_CONFLICT"}, status=409)
            
        # Create core transaction document
        TransactionRepository.create_transaction(user_id, operation, amount_minor, idempotency_key)
            
        # Rule 59: Enqueue Transaction
        queue_item = QueueRepository.enqueue(transaction_id)
        EventService.log_lifecycle(transaction_id, "QUEUED", f"Requested {operation} for {amount_minor} minor units")
        
        return JsonResponse({
            "success": True,
            "message": "Transaction accepted and queued",
            "transaction_id": transaction_id,
            "status": "QUEUED"
        }, status=202)
        
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
TVWS

echo "Wiring URLs..."
cat << 'URLS' > backend/config/urls.py
from django.urls import path
from django.http import JsonResponse
from db.connection import MongoManager
from apps.users.views import login_view
from apps.transactions.views import create_transaction

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
    path('api/auth/login', login_view),
    path('api/transactions', create_transaction),
]
URLS

echo "Done."
