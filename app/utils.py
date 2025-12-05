# app/utils.py
import os
from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta
import uuid

# Config - replace via ENV in production
SECRET_KEY = os.environ.get("SECRET_KEY", "replace_this_secret_for_dev")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", 60*24))  # 1 day

# Hai context: argon2 cho user mới, bcrypt để verify user cũ
pwd_context_new = CryptContext(schemes=["argon2"], deprecated="auto")
pwd_context_old = CryptContext(schemes=["bcrypt"], deprecated="auto")

def hash_password(password: str):
    # luôn hash mới bằng argon2
    return pwd_context_new.hash(password)

def verify_password(plain: str, hashed: str) -> bool:
    # thử verify bằng argon2 trước
    try:
        if pwd_context_new.verify(plain, hashed):
            return True
    except Exception:
        pass
    # thử verify bằng bcrypt cho user cũ
    try:
        if pwd_context_old.verify(plain, hashed):
            return True
    except Exception:
        pass
    return False

def create_access_token(subject: str, expires_minutes: int | None = None) -> dict:
    now = datetime.utcnow()
    expire = now + timedelta(minutes=(expires_minutes or ACCESS_TOKEN_EXPIRE_MINUTES))
    jti = str(uuid.uuid4())
    payload = {"sub": subject, "iat": now, "exp": expire, "jti": jti}
    token = jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)
    return {"access_token": token, "jti": jti}
