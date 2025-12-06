# app/main.py
import os
from fastapi import FastAPI, Depends, HTTPException, Query, BackgroundTasks
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
from fastapi.middleware.cors import CORSMiddleware
import io, requests

from .database import engine, Base, SessionLocal
from . import models, schemas, auth, mqtt_client, utils, ai_ingest
from .auth import role_required

app = FastAPI(title="Traffic Manager (backend)")

# CORS
origins = [
    "http://localhost",
    "http://127.0.0.1",
    "http://localhost:3000",
    "http://localhost:5000",
    "https://traffic-system-1-8qxs.onrender.com",
    "https://traffic-system-production.up.railway.app",   # <-- domain Railway
    "*"  # Cho phép tạm toàn bộ domain (nếu muốn chặt thì bỏ *)
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------- Root ----------
@app.get("/")
def read_root():
    return {"message": "Traffic Manager API is running!"}


"""
# ---------- Static files (frontend nếu có) ----------
static_dir = os.path.join(os.path.dirname(__file__), "..", "static")
if os.path.isdir(static_dir):
    app.mount("/static", StaticFiles(directory=static_dir), name="static")
"""

# ---------- Startup: MQTT + seed admin ----------
@app.on_event("startup")
def startup():
    mqtt_client.start_in_thread()
    db = SessionLocal()
    admin_email = os.environ.get("ADMIN_EMAIL")
    admin_pass = os.environ.get("ADMIN_PASS")
    if admin_email and admin_pass:
        if not db.query(models.User).filter(models.User.email == admin_email).first():
            h = utils.hash_password(admin_pass)
            user = models.User(email=admin_email, hashed_password=h, role="admin", notify=True)
            db.add(user)
            db.commit()
            print("Seeded admin user:", admin_email)
    db.close()

# ---------- Dependency ----------
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ---------- Routers ----------
app.include_router(auth.router)
app.include_router(ai_ingest.router)

# ---------- Light control ----------
@app.get("/api/lights", response_model=list[schemas.LightSettingOut])
def list_lights(db: Session = Depends(get_db), user: models.User = Depends(auth.get_current_user)):
    # all roles can view
    return db.query(models.LightSetting).all()

@app.post("/api/lights", response_model=schemas.LightSettingOut)
def set_light(payload: schemas.LightSettingIn, db: Session = Depends(get_db),
              user: models.User = Depends(role_required(["admin","police"]))):
    row = db.query(models.LightSetting).filter(models.LightSetting.intersection == payload.intersection).first()
    if row:
        row.red = payload.red
        row.yellow = payload.yellow
        row.green = payload.green
    else:
        row = models.LightSetting(intersection=payload.intersection, red=payload.red, yellow=payload.yellow, green=payload.green)
        db.add(row)
    db.commit()
    db.refresh(row)
    mqtt_client.publish_light(row.intersection, row.red, row.yellow, row.green)
    return row

# ---------- Alert logs ----------
@app.get("/api/alerts", response_model=list[schemas.AlertLogOut])
def alerts(limit: int = 50, db: Session = Depends(get_db),
           user: models.User = Depends(role_required(["admin","police"]))):
    return db.query(models.AlertLog).order_by(models.AlertLog.timestamp.desc()).limit(limit).all()

# ---------- Admin: manage users ----------
@app.post("/api/users", response_model=schemas.UserOut)
def create_user(u: schemas.UserCreate, role: str = "police", db: Session = Depends(get_db),
                user: models.User = Depends(role_required(["admin"]))):
    if db.query(models.User).filter(models.User.email == u.email).first():
        raise HTTPException(status_code=400, detail="Email exists")
    hashed = utils.hash_password(u.password)
    new_user = models.User(email=u.email, hashed_password=hashed, role=role, notify=True)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.get("/api/users/me", response_model=schemas.UserOut)
def me(user: models.User = Depends(auth.get_current_user)):
    return user

@app.get("/api/users", response_model=list[schemas.UserOut])
def list_users(db: Session = Depends(get_db), user: models.User = Depends(role_required(["admin"]))):
    return db.query(models.User).all()


"""
# ---------- Camera snapshot ----------
@app.get("/api/camera/snapshot")
def camera_snapshot(url: str = Query(..., description="Full URL to camera snapshot or single-frame endpoint")):
    try:
        r = requests.get(url, timeout=5)
        r.raise_for_status()
        content_type = r.headers.get("Content-Type", "image/jpeg")
        return StreamingResponse(io.BytesIO(r.content), media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to fetch snapshot: {e}")

# ---------- Traffic endpoints ----------
@app.get("/api/traffic/recent", response_model=list[schemas.TrafficOut])
def recent_traffic(limit: int = 100, db: Session = Depends(get_db), user: models.User = Depends(auth.get_current_user)):
    rows = db.query(models.TrafficData).order_by(models.TrafficData.timestamp.desc()).limit(limit).all()
    return list(reversed(rows))

@app.get("/api/traffic/stats")
def traffic_stats(from_ts: str | None = None, to_ts: str | None = None, interval: str = "minute",
                  db: Session = Depends(get_db), user: models.User = Depends(auth.get_current_user)):
    if to_ts:
        to_dt = datetime.fromisoformat(to_ts)
    else:
        to_dt = datetime.utcnow()
    if from_ts:
        from_dt = datetime.fromisoformat(from_ts)
    else:
        from_dt = to_dt - timedelta(hours=1)

    rows = db.query(models.TrafficData).filter(
        models.TrafficData.timestamp >= from_dt,
        models.TrafficData.timestamp <= to_dt
    ).order_by(models.TrafficData.timestamp).all()

    buckets = {}
    for r in rows:
        if interval == "hour":
            key = r.timestamp.replace(minute=0, second=0, microsecond=0).isoformat()
        else:
            key = r.timestamp.replace(second=0, microsecond=0).isoformat()
        buckets.setdefault(key, 0)
        buckets[key] += (r.count or 0)
    series = [{"timestamp": k, "count": buckets[k]} for k in sorted(buckets.keys())]
    return {"from": from_dt.isoformat(), "to": to_dt.isoformat(), "interval": interval, "series": series}
"""
