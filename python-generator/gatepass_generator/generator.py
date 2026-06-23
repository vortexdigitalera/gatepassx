"""Gate pass PDF + QR generation logic for AHUON GatePassX."""

from __future__ import annotations

import io
import os
import warnings
from datetime import datetime
from typing import Optional, List

import qrcode
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm, inch
from reportlab.lib.colors import HexColor, black, white
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from PIL import Image

from .models import GatePass

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


# AHUON brand colors (approximate)
AHUON_GREEN = HexColor("#006400")
AHUON_LIGHT = HexColor("#E8F5E9")
AHUON_GOLD = HexColor("#D4AF37")


def generate_qr_image(data: str, box_size: int = 6, border: int = 2) -> Image.Image:
    """Generate a QR code PIL Image."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=box_size,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    return img


def create_pass_pdf(
    gate_pass: GatePass,
    output_path: str,
    secret: Optional[str] = None,
    include_photo_placeholder: bool = True,
) -> str:
    """
    Generate a professional single gate pass PDF.
    Returns the path written.
    """
    if secret is None:
        secret = _get_qr_secret()
    if not gate_pass.qr_payload:
        gate_pass.compute_qr_payload(secret=secret)

    qr_img = generate_qr_image(gate_pass.qr_payload or "", box_size=5)
    qr_buffer = io.BytesIO()
    qr_img.save(qr_buffer, format="PNG")
    qr_buffer.seek(0)
    qr_reader = ImageReader(qr_buffer)

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    c = canvas.Canvas(output_path, pagesize=A4)
    width, height = A4

    # Header band
    c.setFillColor(AHUON_GREEN)
    c.rect(0, height - 45*mm, width, 45*mm, fill=1, stroke=0)

    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 22)
    c.drawCentredString(width/2, height - 18*mm, "GATEPASSX")
    c.setFont("Helvetica-Bold", 14)
    c.drawCentredString(width/2, height - 27*mm, "EVENT ENTRY GATE PASS")

    c.setFont("Helvetica", 9)
    c.drawCentredString(width/2, height - 35*mm, "Official Event Pass • Verify via QR at gate")

    # Pass ID (large)
    c.setFillColor(black)
    c.setFont("Helvetica-Bold", 18)
    c.drawCentredString(width/2, height - 55*mm, gate_pass.pass_id)

    # Main content box
    margin = 20*mm
    box_top = height - 62*mm
    box_height = 95*mm
    c.setStrokeColor(AHUON_GREEN)
    c.setFillColor(AHUON_LIGHT)
    c.roundRect(margin, box_top - box_height, width - 2*margin, box_height, 5*mm, fill=1, stroke=1)

    # Details
    y = box_top - 12*mm
    left_x = margin + 8*mm
    line_height = 7*mm

    c.setFillColor(black)
    c.setFont("Helvetica-Bold", 11)

    def draw_field(label: str, value: str, y_pos: float):
        c.setFont("Helvetica-Bold", 9)
        c.drawString(left_x, y_pos, label + ":")
        c.setFont("Helvetica", 10)
        c.drawString(left_x + 38*mm, y_pos, value or "-")

    draw_field("Name", gate_pass.full_name, y)
    y -= line_height
    draw_field("ID / Passport / Plate", gate_pass.id_number, y)
    y -= line_height
    draw_field("Phone", gate_pass.phone or "", y)
    y -= line_height
    draw_field("Operator", gate_pass.operator, y)
    y -= line_height
    trip = gate_pass.trip_type or ""
    draw_field("Trip Type", str(trip), y)
    y -= line_height
    draw_field("Validity", f"{gate_pass.valid_from}  →  {gate_pass.valid_to}", y)
    y -= line_height
    draw_field("Gate / Checkpoint", gate_pass.gate or "ALL", y)
    y -= line_height
    draw_field("Group / Ref", gate_pass.group_ref or "", y)
    if gate_pass.vehicle_plate:
        y -= line_height
        draw_field("Vehicle Plate", gate_pass.vehicle_plate, y)

    # Category badge
    c.setFillColor(AHUON_GREEN)
    c.roundRect(width - margin - 45*mm, box_top - 14*mm, 38*mm, 8*mm, 2*mm, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 9)
    c.drawCentredString(width - margin - 26*mm, box_top - 11*mm, str(gate_pass.category))

    # QR Code
    qr_size = 42*mm
    qr_x = width - margin - qr_size - 5*mm
    qr_y = box_top - box_height + 5*mm
    c.drawImage(qr_reader, qr_x, qr_y, width=qr_size, height=qr_size, preserveAspectRatio=True, mask='auto')

    # Instructions under QR
    c.setFillColor(black)
    c.setFont("Helvetica", 7)
    c.drawCentredString(qr_x + qr_size/2, qr_y - 4*mm, "SCAN TO VERIFY")

    # Footer
    c.setFont("Helvetica", 8)
    c.drawString(margin, 18*mm, f"Issued: {gate_pass.issued_at.strftime('%Y-%m-%d %H:%M UTC')} by {gate_pass.issued_by}")
    c.drawRightString(width - margin, 18*mm, "GatePassX • Secure Event Entry")

    # Signature / stamp area
    c.setStrokeColor(HexColor("#888888"))
    c.setDash(3, 2)
    c.line(margin, 28*mm, margin + 60*mm, 28*mm)
    c.setDash()
    c.setFont("Helvetica", 7)
    c.drawString(margin, 24*mm, "Authorized Signature / Stamp")

    c.save()
    return output_path


def generate_batch_pdfs(
    passes: List[GatePass],
    output_dir: str,
    secret: Optional[str] = None,
) -> List[str]:
    """Generate one PDF per pass. Returns list of written paths."""
    os.makedirs(output_dir, exist_ok=True)
    paths = []
    for p in passes:
        safe_id = p.pass_id.replace("/", "-").replace(" ", "_")
        out = os.path.join(output_dir, f"{safe_id}.pdf")
        create_pass_pdf(p, out, secret=secret)
        paths.append(out)
    return paths


def create_passes_sheet(
    passes: List[GatePass],
    output_path: str,
    secret: Optional[str] = None,
    cols: int = 2,
) -> str:
    """Create a multi-pass printable sheet (e.g. 2-up on A4)."""
    # Simplified: for demo, just generate first pass large + note others
    # For real use one could layout multiple small cards.
    if not passes:
        raise ValueError("No passes provided")
    # For MVP we generate individual + a simple index sheet
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    c = canvas.Canvas(output_path, pagesize=A4)
    width, height = A4

    c.setFillColor(AHUON_GREEN)
    c.rect(0, height-25*mm, width, 25*mm, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(width/2, height - 15*mm, "GATEPASSX — Event Pass Batch Sheet")

    c.setFillColor(black)
    c.setFont("Helvetica", 10)
    y = height - 35*mm
    c.drawString(15*mm, y, f"Total passes: {len(passes)}   Generated: {datetime.utcnow().isoformat()}")
    y -= 8*mm

    for i, gp in enumerate(passes[:12]):  # limit for demo sheet
        c.setFont("Helvetica-Bold", 9)
        c.drawString(15*mm, y, f"{i+1}. {gp.pass_id}  —  {gp.full_name} ({gp.category})")
        y -= 5*mm
        if y < 25*mm:
            c.showPage()
            y = height - 25*mm

    c.save()
    # Also generate individual files next to the sheet for convenience
    ind_dir = os.path.join(os.path.dirname(output_path), "individuals")
    generate_batch_pdfs(passes, ind_dir, secret=secret)
    return output_path
