# app/auth.py
from fastapi import APIRouter, Depends, HTTPException, Header, Security
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from . import models, schemas, utils, database, notify
from jose import jwt, JWTError
from .utils import create_access_token
from typing import Optional
import uuid
from datetime import datetime, timedelta
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
router = APIRouter(prefix="/auth")
import string
import random

def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

# dangki
@router.post("/register/send-code")
def send_verify_email(data: schemas.RegisterSendCodeIn, db: Session = Depends(get_db)):

    # email tồn tại → không cho tạo user mới
    if db.query(models.User).filter(models.User.email == data.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")

    # check password match
    if data.password != data.retype_password:
        raise HTTPException(status_code=400, detail="Passwords do not match")

    import random
    code = f"{random.randint(100000,999999)}"
    exp = datetime.utcnow() + timedelta(minutes=10)

    # Xóa record cũ nếu có
    db.query(models.EmailVerify).filter(models.EmailVerify.email == data.email).delete()

    rec = models.EmailVerify(
        email=data.email,
        firstname=data.firstname,
        lastname=data.lastname,
        password=utils.hash_password(data.password),
        code=code,
        expires_at=exp
    )

    db.add(rec)
    db.commit()

    # gửi email
    notify.send_mail_sync(
        [data.email],
        "Traffic Manager – Email Verification Code",
        f"Hello,\n\n"
        f"You are registering an account on the Traffic Manager system.\n\n"
        f"Your verification code is:\n\n"
        f"    {code}\n\n"
        f"This verification code is valid for 10 minutes.\n"
        f"Please do not share this code with anyone.\n\n"
        f"If you did not request this email, please ignore it.\n\n"
        f"Best regards,\n"
        f"Traffic Manager Team"
    )

    return {"message": "Verification code sent"}

@router.post("/register/confirm", response_model=schemas.UserOut)
def confirm_register(data: schemas.RegisterConfirmIn, db: Session = Depends(get_db)):

    rec = db.query(models.EmailVerify).filter(
        models.EmailVerify.email == data.email,
        models.EmailVerify.code == data.code
    ).first()

    if not rec:
        raise HTTPException(status_code=400, detail="Invalid verification code")

    if rec.expires_at < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Verification code expired")

    # tạo user
    user = models.User(
        email=rec.email,
        hashed_password=rec.password,
        firstname=rec.firstname,
        lastname=rec.lastname,
        role="viewer",
        notify=True
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    # xóa record verify
    db.delete(rec)
    db.commit()

    return user


# register - default as viewer
#@router.post("/register", response_model=schemas.UserOut)
#def register(u: schemas.UserCreate, db: Session = Depends(get_db)):
#   if db.query(models.User).filter(models.User.email == u.email).first():
#        raise HTTPException(status_code=400, detail="Email already registered")
#    hashed = utils.hash_password(u.password)
#    user = models.User(email=u.email, hashed_password=hashed, role="viewer", notify=True)
#    db.add(user); db.commit(); db.refresh(user)
#    return user


# login: returns token (with jti)
@router.post("/token", response_model=schemas.TokenResp)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.email == form_data.username).first()
    if not user or not utils.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token_data = utils.create_access_token(subject=user.email)
    return {"access_token": token_data["access_token"], "token_type": "bearer"}


# helper to get current user from Bearer token
security = HTTPBearer()
def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security), db: Session = Depends(get_db)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, utils.SECRET_KEY, algorithms=["HS256"])
        email: str = payload.get("sub")
        jti: str = payload.get("jti")
        if email is None:
            raise HTTPException(status_code=401, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=401, detail="Could not validate token")
    # check blocklist
    if db.query(models.TokenBlocklist).filter(models.TokenBlocklist.jti == jti).first():
        raise HTTPException(status_code=401, detail="Token revoked")
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user


# logout: revoke token by jti
@router.post("/logout")
def logout(credentials: HTTPAuthorizationCredentials = Security(security), db: Session = Depends(get_db)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, utils.SECRET_KEY, algorithms=["HS256"])
        jti = payload.get("jti")
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    # store to blocklist
    db_blk = models.TokenBlocklist(jti=jti)
    db.add(db_blk); db.commit()
    return {"ok": True}



#phan quyen : role(admin/viewer/police)
def role_required(allowed_roles: list[str]):
    def wrapper(user: models.User = Depends(get_current_user)):
        if user.role not in allowed_roles:
            raise HTTPException(status_code=403, detail="Insufficient privileges")
        return user
    return wrapper

#quen pass
def generate_password(length: int = 16):
    chars = string.ascii_letters + string.digits + "!@#$%^&*()-_=+"
    return ''.join(random.choice(chars) for _ in range(length))

@router.post("/password/forgot")
def forgot_password(data: schemas.ForgotPasswordIn, db: Session = Depends(get_db)):
    email = data.email
    user = db.query(models.User).filter(models.User.email == email).first()
    if not user:
        # Không tiết lộ email tồn tại hay không
        return {"ok": True}

    # Tạo mật khẩu mạnh
    new_pass = generate_password()

    # Hash và cập nhật luôn
    user.hashed_password = utils.hash_password(new_pass)
    db.commit()

    # Gửi email cho user
    notify.send_mail_sync(
        [email],
        "Your new password for Traffic Manager",
        f"Your new password is:\n\n{new_pass}\n\nYou can login immediately with this password. Change it later if you want."
    )

    return {"message": "A new password has been sent to your email"}
# doi pass
@router.post("/password/change")
def change_password(
    data: schemas.ChangePasswordIn,
    user: models.User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Kiểm tra mật khẩu cũ
    if not utils.verify_password(data.old_password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Old password incorrect")

    # Kiểm tra new_password == retype_password
    if data.new_password != data.retype_password:
        raise HTTPException(status_code=400, detail="Retype password does not match")

    # Cập nhật mật khẩu mới
    user.hashed_password = utils.hash_password(data.new_password)
    db.commit()

    return {"message": "Password changed successfully"}
# @router.post("/register", response_model=schemas.UserOut)
# def register(u: schemas.UserCreate, db: Session = Depends(get_db)):

#     # Kiểm tra email tồn tại
#     existing = db.query(models.User).filter(models.User.email == u.email).first()
#     if existing:
#         raise HTTPException(status_code=400, detail="Email already registered")

#     # Hash mật khẩu
#     hashed = utils.hash_password(u.password)

#     # Tạo user
#     user = models.User(
#         email=u.email,
#         hashed_password=hashed,
#         role="viewer",
#         notify=True
#     )

#     db.add(user)
#     db.commit()
#     db.refresh(user)

#     return user