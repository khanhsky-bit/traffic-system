# app/reset_passwords.py
from app import utils, database, models

db = database.SessionLocal()
users = db.query(models.User).all()

for u in users:
    new_pass = "Password123!"  # hoặc generate random
    u.hashed_password = utils.hash_password(new_pass)
    print(f"User {u.email} reset password to {new_pass}")

db.commit()
db.close()
print("All passwords reset to Argon2")
