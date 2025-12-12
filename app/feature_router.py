# app/feature_router.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from .database import get_db
from . import models, schemas, auth

router = APIRouter(prefix="/api/features", tags=["features"])


# =========================
# ADMIN GUARD
# =========================
def admin_required(user=Depends(auth.get_current_user)):
    if user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin only")
    return user


# =========================
# GET ALL FEATURES
# =========================
@router.get("/", response_model=schemas.FeatureList)
def get_features(db: Session = Depends(get_db)):
    features = db.query(models.Feature).all()
    return {
        "features": [
            {"featureId": f.feature_id, "isEnabled": f.is_enabled}
            for f in features
        ]
    }


# =========================
# UPDATE FEATURE (ADMIN)
# =========================
@router.post("/", response_model=schemas.FeatureOut)
def update_feature(
    data: schemas.FeatureBase,
    db: Session = Depends(get_db),
    admin=Depends(admin_required),
):
    feature = (
        db.query(models.Feature)
        .filter(models.Feature.feature_id == data.featureId)
        .first()
    )

    if not feature:
        feature = models.Feature(
            feature_id=data.featureId,
            is_enabled=data.isEnabled,
        )
        db.add(feature)
    else:
        feature.is_enabled = data.isEnabled

    db.commit()
    db.refresh(feature)

    return {
        "featureId": feature.feature_id,
        "isEnabled": feature.is_enabled,
    }
