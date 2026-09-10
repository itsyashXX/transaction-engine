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
