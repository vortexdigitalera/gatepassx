"""Utility helpers (e.g. shared verification logic)."""

import json
import hashlib
from typing import Dict, Any, Tuple


def verify_qr_payload(payload: str, secret: str = "ahuon-gatepass-secret-2026") -> Tuple[bool, Dict[str, Any]]:
    """Verify a QR payload string. Returns (is_valid, parsed_data)."""
    try:
        data = json.loads(payload)
    except Exception:
        return False, {"error": "invalid_json"}

    # Recompute signature if present
    if "sig" in data:
        sig = data.pop("sig")
        payload_no_sig = json.dumps(data, sort_keys=True)
        expected = hashlib.sha256((payload_no_sig + secret).encode("utf-8")).hexdigest()[:16]
        if expected != sig:
            return False, {"error": "bad_signature", "data": data}
    return True, data
