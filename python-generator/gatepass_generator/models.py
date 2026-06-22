"""Core data models for AHUON GatePassX."""

from __future__ import annotations

from datetime import datetime, date
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator
import hashlib
import json


class TripType(str, Enum):
    HAJJ = "HAJJ"
    UMRAH = "UMRAH"


class PassCategory(str, Enum):
    PILGRIM = "PILGRIM"
    STAFF = "STAFF"
    VEHICLE = "VEHICLE"
    VISITOR = "VISITOR"
    VIP = "VIP"


class GatePass(BaseModel):
    """AHUON Gate Pass record."""

    pass_id: str = Field(..., description="Unique pass identifier e.g. AHUON-HAJJ-2026-000042")
    category: PassCategory
    full_name: str
    id_number: str = Field(..., description="Passport, NIN, or license plate for vehicles")
    phone: Optional[str] = None
    operator: str = Field(..., description="AHUON registered tour operator / company")
    trip_type: Optional[TripType] = None
    valid_from: date
    valid_to: date
    gate: Optional[str] = Field(None, description="Designated gate or checkpoint")
    group_ref: Optional[str] = Field(None, description="Flight, bus, or group reference")
    vehicle_plate: Optional[str] = None
    issued_at: datetime = Field(default_factory=datetime.utcnow)
    issued_by: str = "system"
    notes: Optional[str] = None

    # Computed / populated later
    qr_payload: Optional[str] = None  # The exact string encoded in the QR

    model_config = {"use_enum_values": True}

    @field_validator("valid_to")
    @classmethod
    def check_validity(cls, v: date, info):
        data = info.data
        if "valid_from" in data and v < data["valid_from"]:
            raise ValueError("valid_to must be on or after valid_from")
        return v

    def to_verification_dict(self, secret: Optional[str] = None) -> dict:
        """Return the minimal dict used for QR and verification."""
        base = {
            "pid": self.pass_id,
            "nm": self.full_name,
            "cat": self.category.value if isinstance(self.category, PassCategory) else self.category,
            "idn": self.id_number,
            "op": self.operator,
            "vf": self.valid_from.isoformat(),
            "vt": self.valid_to.isoformat(),
            "gt": self.gate or "",
        }
        if self.group_ref:
            base["grp"] = self.group_ref
        if self.vehicle_plate:
            base["vp"] = self.vehicle_plate

        if secret:
            # Simple integrity signature (HMAC-like using sha256 of json+secret)
            payload_str = json.dumps(base, sort_keys=True)
            sig = hashlib.sha256((payload_str + secret).encode("utf-8")).hexdigest()[:16]
            base["sig"] = sig
        return base

    def compute_qr_payload(self, secret: Optional[str] = None) -> str:
        """Produce the string that will be put into the QR code."""
        data = self.to_verification_dict(secret=secret)
        payload = json.dumps(data, separators=(",", ":"))
        self.qr_payload = payload
        return payload

    @classmethod
    def from_dict(cls, data: dict) -> "GatePass":
        return cls(**data)


class PassLogEntry(BaseModel):
    """Audit log entry for entry/exit events (used by mobile + reports)."""

    timestamp: datetime = Field(default_factory=datetime.utcnow)
    pass_id: str
    action: str  # "ENTRY" | "EXIT" | "REJECTED"
    gate: Optional[str] = None
    scanned_by: Optional[str] = None
    device_id: Optional[str] = None
    notes: Optional[str] = None
    valid: bool = True
