"""GatePassX — Dinner & Event Gate Pass Generator."""

from .models import GatePass, PassCategory, EventType, PassLogEntry, PassManifest, get_qr_secret
from .generator import (
    create_pass_pdf,
    generate_batch_pdfs,
    create_passes_sheet,
    generate_qr_image,
    save_qr_image,
    export_pdf_as_image,
    export_batch_images,
    export_template_as_image,
    lock_input_file,
    check_input_lock,
    unlock_input_file,
)

__version__ = "1.0.0"
__all__ = [
    "GatePass",
    "PassCategory",
    "EventType",
    "PassLogEntry",
    "PassManifest",
    "get_qr_secret",
    "create_pass_pdf",
    "generate_batch_pdfs",
    "create_passes_sheet",
    "generate_qr_image",
    "save_qr_image",
    "export_pdf_as_image",
    "export_batch_images",
    "export_template_as_image",
    "lock_input_file",
    "check_input_lock",
    "unlock_input_file",
]
