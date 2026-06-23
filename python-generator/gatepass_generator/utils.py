"""Utility helpers for QR payload verification."""

import hmac
import hashlib
import json
from typing import Dict, Any, Tuple, Optional

from .models import get_qr_secret


def verify_qr_payload(payload: str, secret: Optional[str] = None) -> Tuple[bool, Dict[str, Any]]:
    """Verify a QR payload string. Returns (is_valid, parsed_data).

    Checks the HMAC signature if present, and returns the parsed data dict.
    """
    if secret is None:
        secret = get_qr_secret()

    try:
        data = json.loads(payload)
    except Exception:
        return False, {"error": "invalid_json"}

    if "sig" in data:
        sig = data.pop("sig")
        payload_no_sig = json.dumps(data, sort_keys=True)
        expected = hmac.new(
            secret.encode(),
            payload_no_sig.encode(),
            hashlib.sha256,
        ).hexdigest()[:16]
        if expected != sig:
            return False, {"error": "bad_signature", "data": data}

    return True, data
