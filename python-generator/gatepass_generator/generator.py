"""Gate pass PDF + QR code generation for GatePassX events."""

from __future__ import annotations

import io
import os
from datetime import datetime
from typing import Optional, List

import qrcode
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, black, white
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from PIL import Image

from .models import GatePass, get_qr_secret

# Brand palette
BRAND_PRIMARY = HexColor("#1A1A2E")
BRAND_ACCENT = HexColor("#16213E")
BRAND_GOLD = HexColor("#D4AF37")
BRAND_LIGHT = HexColor("#F5F0E8")
BRAND_MINT = HexColor("#E8F5E9")
BRAND_TEXT = HexColor("#333333")
BRAND_MUTED = HexColor("#777777")

# Category accent colours
CATEGORY_COLORS = {
    "GUEST": HexColor("#1B7A1B"),
    "VIP": HexColor("#D4AF37"),
    "STAFF": HexColor("#1565C0"),
    "SPEAKER": HexColor("#7B1FA2"),
    "PERFORMER": HexColor("#E65100"),
    "MEDIA": HexColor("#C62828"),
    "VENDOR": HexColor("#00838F"),
    "EXHIBITOR": HexColor("#00695C"),
}


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
    return qr.make_image(fill_color="black", back_color="white")


def save_qr_image(data: str, output_path: str, box_size: int = 10, border: int = 3) -> str:
    """Save a high-resolution QR code PNG to disk."""
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    img = generate_qr_image(data, box_size=box_size, border=border)
    img.save(output_path, format="PNG")
    return output_path


def _draw_field(c, x: float, y: float, label: str, value: str, label_w: float = 38 * mm):
    """Draw a labelled field on the PDF canvas."""
    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(BRAND_MUTED)
    c.drawString(x, y, label + ":")
    c.setFont("Helvetica", 10)
    c.setFillColor(BRAND_TEXT)
    c.drawString(x + label_w, y, value or "—")


def create_pass_pdf(
    gate_pass: GatePass,
    output_path: str,
    secret: Optional[str] = None,
) -> str:
    """Generate a professional single event gate pass PDF (credit-card style on A4)."""
    if secret is None:
        secret = get_qr_secret()
    if not gate_pass.qr_payload:
        gate_pass.compute_qr_payload(secret=secret)

    qr_img = generate_qr_image(gate_pass.qr_payload or "", box_size=5)
    qr_buf = io.BytesIO()
    qr_img.save(qr_buf, format="PNG")
    qr_buf.seek(0)
    qr_reader = ImageReader(qr_buf)

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    cat_color = CATEGORY_COLORS.get(
        gate_pass.category.value if hasattr(gate_pass.category, "value") else str(gate_pass.category),
        BRAND_PRIMARY,
    )

    c = canvas.Canvas(output_path, pagesize=A4)
    w, h = A4

    # --- Header band ---
    c.setFillColor(BRAND_PRIMARY)
    c.rect(0, h - 48 * mm, w, 48 * mm, fill=1, stroke=0)

    # Gold accent line
    c.setStrokeColor(BRAND_GOLD)
    c.setLineWidth(2)
    c.line(0, h - 48 * mm, w, h - 48 * mm)

    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 24)
    c.drawCentredString(w / 2, h - 18 * mm, "GATEPASSX")
    c.setFont("Helvetica", 12)
    c.setFillColor(BRAND_GOLD)
    c.drawCentredString(w / 2, h - 27 * mm, "EVENT GATE PASS")
    c.setFont("Helvetica", 8)
    c.setFillColor(HexColor("#AAAAAA"))
    c.drawCentredString(w / 2, h - 35 * mm, f"{gate_pass.event_name}  •  {gate_pass.event_type}")

    # --- Event name banner ---
    c.setFillColor(BRAND_ACCENT)
    c.rect(0, h - 58 * mm, w, 10 * mm, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 11)
    c.drawCentredString(w / 2, h - 54.5 * mm, gate_pass.event_name)

    # --- Pass ID ---
    c.setFillColor(BRAND_PRIMARY)
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(w / 2, h - 68 * mm, gate_pass.pass_id)

    # --- Main content card ---
    margin = 18 * mm
    card_top = h - 74 * mm
    card_h = 100 * mm

    # Card background
    c.setFillColor(BRAND_LIGHT)
    c.setStrokeColor(HexColor("#DDDDDD"))
    c.setLineWidth(0.5)
    c.roundRect(margin, card_top - card_h, w - 2 * margin, card_h, 4 * mm, fill=1, stroke=1)

    # Category badge (top-right of card)
    badge_text = str(gate_pass.category)
    badge_w = max(len(badge_text) * 2.2 * mm, 28 * mm)
    c.setFillColor(cat_color)
    c.roundRect(w - margin - badge_w - 6 * mm, card_top - 10 * mm, badge_w, 7 * mm, 2 * mm, fill=1, stroke=0)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 8)
    c.drawCentredString(w - margin - badge_w / 2 - 6 * mm, card_top - 7.5 * mm, badge_text)

    # Detail fields
    left_x = margin + 8 * mm
    y = card_top - 16 * mm
    lh = 7 * mm

    _draw_field(c, left_x, y, "Name", gate_pass.full_name)
    y -= lh
    _draw_field(c, left_x, y, "ID Number", gate_pass.id_number)
    y -= lh
    if gate_pass.phone:
        _draw_field(c, left_x, y, "Phone", gate_pass.phone)
        y -= lh
    if gate_pass.email:
        _draw_field(c, left_x, y, "Email", gate_pass.email)
        y -= lh
    _draw_field(c, left_x, y, "Organizer", gate_pass.organizer)
    y -= lh
    _draw_field(c, left_x, y, "Valid", f"{gate_pass.valid_from}  →  {gate_pass.valid_to}")
    y -= lh
    if gate_pass.gate:
        _draw_field(c, left_x, y, "Gate", gate_pass.gate)
        y -= lh
    if gate_pass.table_number:
        _draw_field(c, left_x, y, "Table / Seat", gate_pass.table_number)
        y -= lh
    if gate_pass.group_ref:
        _draw_field(c, left_x, y, "Reference", gate_pass.group_ref)
        y -= lh

    # --- QR Code (bottom-right) ---
    qr_size = 40 * mm
    qr_x = w - margin - qr_size - 5 * mm
    qr_y = card_top - card_h + 5 * mm
    c.drawImage(qr_reader, qr_x, qr_y, width=qr_size, height=qr_size, preserveAspectRatio=True, mask="auto")

    c.setFillColor(BRAND_MUTED)
    c.setFont("Helvetica", 7)
    c.drawCentredString(qr_x + qr_size / 2, qr_y - 4 * mm, "SCAN TO VERIFY")

    # --- Footer ---
    c.setFont("Helvetica", 7)
    c.setFillColor(BRAND_MUTED)
    c.drawString(margin, 20 * mm, f"Issued: {gate_pass.issued_at.strftime('%Y-%m-%d %H:%M UTC')} by {gate_pass.issued_by}")
    c.drawRightString(w - margin, 20 * mm, "GatePassX • Secure Event Entry")

    # Signature line
    c.setStrokeColor(HexColor("#BBBBBB"))
    c.setDash(3, 2)
    c.setLineWidth(0.5)
    c.line(margin, 30 * mm, margin + 55 * mm, 30 * mm)
    c.setDash()
    c.setFont("Helvetica", 6)
    c.drawString(margin, 26 * mm, "Authorized Signature / Stamp")

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
) -> str:
    """Create a summary index sheet listing all passes (A4)."""
    if not passes:
        raise ValueError("No passes provided")

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    c = canvas.Canvas(output_path, pagesize=A4)
    w, h = A4

    # Header
    c.setFillColor(BRAND_PRIMARY)
    c.rect(0, h - 28 * mm, w, 28 * mm, fill=1, stroke=0)
    c.setStrokeColor(BRAND_GOLD)
    c.setLineWidth(1.5)
    c.line(0, h - 28 * mm, w, h - 28 * mm)
    c.setFillColor(white)
    c.setFont("Helvetica-Bold", 16)
    c.drawCentredString(w / 2, h - 14 * mm, "GATEPASSX — Batch Summary")
    c.setFont("Helvetica", 9)
    c.setFillColor(BRAND_GOLD)
    c.drawCentredString(w / 2, h - 22 * mm, f"{passes[0].event_name}")

    c.setFillColor(BRAND_TEXT)
    c.setFont("Helvetica", 9)
    y = h - 38 * mm
    c.drawString(15 * mm, y, f"Total passes: {len(passes)}   Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}")
    y -= 4 * mm

    # Table header
    c.setStrokeColor(BRAND_PRIMARY)
    c.setLineWidth(0.5)
    c.line(15 * mm, y, w - 15 * mm, y)
    y -= 5 * mm
    c.setFont("Helvetica-Bold", 8)
    c.setFillColor(BRAND_PRIMARY)
    c.drawString(15 * mm, y, "#")
    c.drawString(22 * mm, y, "PASS ID")
    c.drawString(72 * mm, y, "NAME")
    c.drawString(125 * mm, y, "CATEGORY")
    c.drawString(155 * mm, y, "TABLE")
    c.drawString(175 * mm, y, "GATE")
    y -= 3 * mm
    c.line(15 * mm, y, w - 15 * mm, y)
    y -= 5 * mm

    c.setFont("Helvetica", 8)
    for i, gp in enumerate(passes):
        if y < 20 * mm:
            c.showPage()
            y = h - 20 * mm
        c.setFillColor(BRAND_TEXT)
        c.drawString(15 * mm, y, str(i + 1))
        c.drawString(22 * mm, y, gp.pass_id)
        c.drawString(72 * mm, y, gp.full_name[:25])
        cat = gp.category.value if hasattr(gp.category, "value") else str(gp.category)
        c.drawString(125 * mm, y, cat)
        c.drawString(155 * mm, y, gp.table_number or "—")
        c.drawString(175 * mm, y, gp.gate or "—")
        y -= 5 * mm

    c.save()

    # Also generate individual PDFs alongside the sheet
    ind_dir = os.path.join(os.path.dirname(output_path), "individuals")
    generate_batch_pdfs(passes, ind_dir, secret=secret)
    return output_path
