"""Core data models for GatePassX — Dinner & Event Gate Pass system."""

from __future__ import annotations

import hmac
import hashlib
import json
import os
import warnings
from datetime import datetime, date
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator

QR_SECRET_ENV = "GATEPASSX_QR_SECRET"
_QR_SECRET_DEV_DEFAULT = "gpx-dev-secret-do-not-use-in-production"


def get_qr_secret() -> str:
    """Return the QR signing secret from env, or warn and fall back to dev default."""
    secret = os.environ.get(QR_SECRET_ENV)
    if not secret:
        warnings.warn(
            f"{QR_SECRET_ENV} not set — using insecure dev default. "
            f"Set {QR_SECRET_ENV} for production.",
            stacklevel=2,
        )
        return _QR_SECRET_DEV_DEFAULT
    return secret


class EventType(str, Enum):
    DINNER = "DINNER"
    GALA = "GALA"
    CONFERENCE = "CONFERENCE"
    WEDDING = "WEDDING"
    CONCERT = "CONCERT"
    FESTIVAL = "FESTIVAL"
    EXHIBITION = "EXHIBITION"
    CORPORATE = "CORPORATE"
    PRIVATE_PARTY = "PRIVATE_PARTY"
    OTHER = "OTHER"


class PassCategory(str, Enum):
    GUEST = "GUEST"
    VIP = "VIP"
    STAFF = "STAFF"
    SPEAKER = "SPEAKER"
    PERFORMER = "PERFORMER"
    MEDIA = "MEDIA"
    VENDOR = "VENDOR"
    EXHIBITOR = "EXHIBITOR"


class GatePass(BaseModel):
    """GatePassX event gate pass record."""

    pass_id: str = Field(..., description="Unique pass identifier, e.g. GPX-DINNER-2026-000042")
    event_name: str = Field("General Event", description="Name of the event")
    event_type: EventType = Field(EventType.DINNER)
    category: PassCategory = Field(PassCategory.GUEST)
    full_name: str
    id_number: str = Field(..., description="ID card, passport, NIN, or registration number")
    phone: Optional[str] = None
    email: Optional[str] = None
    organizer: str = Field("Event Organizer", description="Event organizer or hosting company")
    valid_from: date
    valid_to: date
    gate: Optional[str] = Field(None, description="Designated entrance gate or checkpoint")
    table_number: Optional[str] = Field(None, description="Table or seat assignment (for dinners/galas)")
    group_ref: Optional[str] = Field(None, description="Group, booking, or invitation reference")
    issued_at: datetime = Field(default_factory=datetime.utcnow)
    issued_by: str = "GatePassX"
    notes: Optional[str] = None

    qr_payload: Optional[str] = None

    model_config = {"use_enum_values": True}

    @field_validator("valid_to")
    @classmethod
    def check_validity(cls, v: date, info):
        data = info.data
        if "valid_from" in data and v < data["valid_from"]:
            raise ValueError("valid_to must be on or after valid_from")
        return v

    def to_verification_dict(self, secret: Optional[str] = None) -> dict:
        """Return the minimal dict embedded in the QR code."""
        base: dict = {
            "pid": self.pass_id,
            "ev": self.event_name,
            "nm": self.full_name,
            "cat": self.category.value if isinstance(self.category, PassCategory) else self.category,
            "idn": self.id_number,
            "org": self.organizer,
            "vf": self.valid_from.isoformat(),
            "vt": self.valid_to.isoformat(),
            "gt": self.gate or "",
        }
        if self.table_number:
            base["tbl"] = self.table_number
        if self.group_ref:
            base["grp"] = self.group_ref

        if secret:
            sig = hmac.new(
                secret.encode(),
                json.dumps(base, sort_keys=True).encode(),
                hashlib.sha256,
            ).hexdigest()[:16]
            base["sig"] = sig
        return base

    def compute_qr_payload(self, secret: Optional[str] = None) -> str:
        """Produce the JSON string that will be encoded in the QR code."""
        data = self.to_verification_dict(secret=secret)
        payload = json.dumps(data, separators=(",", ":"))
        self.qr_payload = payload
        return payload

    @classmethod
    def from_qr_payload(cls, payload: str) -> "GatePass":
        """Reconstruct a GatePass from a QR payload string (no signature verification)."""
        data = json.loads(payload)
        return cls(
            pass_id=data.get("pid", "UNKNOWN"),
            event_name=data.get("ev", "Event"),
            full_name=data.get("nm", ""),
            category=PassCategory(data.get("cat", "GUEST")),
            id_number=data.get("idn", ""),
            organizer=data.get("org", "Unknown"),
            valid_from=date.fromisoformat(data["vf"]),
            valid_to=date.fromisoformat(data["vt"]),
            gate=data.get("gt") or None,
            table_number=data.get("tbl"),
            group_ref=data.get("grp"),
        )


class PassLogEntry(BaseModel):
    """Audit log entry for entry/exit events."""

    timestamp: datetime = Field(default_factory=datetime.utcnow)
    pass_id: str
    action: str  # "ENTRY" | "EXIT" | "REJECTED"
    gate: Optional[str] = None
    scanned_by: Optional[str] = None
    device_id: Optional[str] = None
    notes: Optional[str] = None
    valid: bool = True
