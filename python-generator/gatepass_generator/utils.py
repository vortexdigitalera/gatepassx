"""Utility helpers (e.g. shared verification logic)."""

import hmac
import hashlib
import json
import os
import warnings
from typing import Dict, Any, Tuple


_QR_SECRET_ENV_VAR = "AHUON_QR_SECRET"
_QR_SECRET_DEV_DEFAULT = "ahuon-dev-secret-do-not-use-in-production"


def _get_qr_secret() -> str:
    secret = os.environ.get(_QR_SECRET_ENV_VAR)
    if not secret:
        warnings.warn(
            f"{_QR_SECRET_ENV_VAR} not set — using insecure dev default. "
            f"Set {_QR_SECRET_ENV_VAR} in production."
        )
        secret = _QR_SECRET_DEV_DEFAULT
    return secret


def verify_qr_payload(payload: str, secret: str | None = None) -> Tuple[bool, Dict[str, Any]]:
    """Verify a QR payload string. Returns (is_valid, parsed_data).

    If *secret* is None, reads from the AHUON_QR_SECRET env var (or dev default).
    """
    if secret is None:
        secret = _get_qr_secret()

    try:
        data = json.loads(payload)
    except Exception:
        return False, {"error": "invalid_json"}

    if "sig" in data:
        sig = data.pop("sig")
        payload_no_sig = json.dumps(data, sort_keys=True)
        expected = hmac.new(
            secret.encode("utf-8"),
            payload_no_sig.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()[:16]
        if expected != sig:
            return False, {"error": "bad_signature", "data": data}
    return True, data
