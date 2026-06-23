"""GatePassX — Dinner & Event Gate Pass Generator."""

from .models import GatePass, PassCategory, EventType, PassLogEntry, get_qr_secret
from .generator import (
    create_pass_pdf,
    generate_batch_pdfs,
    create_passes_sheet,
    generate_qr_image,
    save_qr_image,
)

__version__ = "1.0.0"
__all__ = [
    "GatePass",
    "PassCategory",
    "EventType",
    "PassLogEntry",
    "get_qr_secret",
    "create_pass_pdf",
    "generate_batch_pdfs",
    "create_passes_sheet",
    "generate_qr_image",
    "save_qr_image",
]
