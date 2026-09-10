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
