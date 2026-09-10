import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from db.connection import MongoManager
from db.repositories.user_repository import UserRepository
from db.repositories.account_repository import AccountRepository

def seed():
    print("Running Development Seed...")
    db = MongoManager.get_db()
    
    # Check if admin exists
    if not UserRepository.find_by_username("sarvesh"):
        print("Creating admin user 'sarvesh' (Rule 26)...")
        user_id = UserRepository.create_user("sarvesh", "sarvesh@suyal", "ADMIN")
        AccountRepository.ensure_account(user_id)
    else:
        print("Admin user already exists. Skipping.")
        
    # Check if demo user exists
    if not UserRepository.find_by_username("demo_user"):
        print("Creating demo user 'demo_user'...")
        user_id = UserRepository.create_user("demo_user", "password123", "USER")
        AccountRepository.ensure_account(user_id)
        # Give them some initial demo balance
        AccountRepository.atomic_add(user_id, 100000) # 1000 INR
    else:
        print("Demo user already exists. Skipping.")
        
    print("Seed complete. Preserved existing data.")

if __name__ == '__main__':
    seed()
