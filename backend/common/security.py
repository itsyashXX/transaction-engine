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
