from db.repositories.user_repository import UserRepository
from common.security import verify_password, generate_token

class AuthenticationService:
    @classmethod
    def login(cls, username: str, password: str):
        user = UserRepository.find_by_username(username)
        if not user or not verify_password(password, user['password_hash']):
            raise ValueError("AUTH_INVALID")
            
        if user['status'] != 'ACTIVE':
            raise ValueError("FORBIDDEN")
            
        token = generate_token(str(user['_id']), user['role'])
        return {
            "token": token,
            "role": user['role'],
            "username": user['username']
        }
