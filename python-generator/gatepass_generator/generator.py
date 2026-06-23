"""Gate pass PDF + QR code generation for GatePassX events."""

from __future__ import annotations

import io
import os
from datetime import datetime
from pathlib import Path
from typing import Optional, List

import qrcode
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib.colors import HexColor, black, white, Color
from reportlab.pdfgen import canvas
from reportlab.lib.utils import ImageReader
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from PIL import Image

from .models import GatePass, PassDesignSettings, PassManifest, QRAlignment, get_qr_secret

# ── Font registration ────────────────────────────────────────────────────────

_FONTS_DIR = Path(__file__).parent / "fonts"
_FONTS_REGISTERED = False


def register_fonts():
    """Register Bricolage Grotesque font family with ReportLab."""
    global _FONTS_REGISTERED
    if _FONTS_REGISTERED:
        return

    variable = _FONTS_DIR / "BricolageGrotesque-Variable.ttf"
    bold_static = _FONTS_DIR / "BricolageGrotesque-Bold.ttf"

    if variable.exists():
        pdfmetrics.registerFont(TTFont("BricolageGrotesque", str(variable)))
    if bold_static.exists():
        pdfmetrics.registerFont(TTFont("BricolageGrotesque-Bold", str(bold_static)))

    if variable.exists() and bold_static.exists():
        pdfmetrics.registerFontFamily(
            "BricolageGrotesque",
            normal="BricolageGrotesque",
            bold="BricolageGrotesque-Bold",
        )
    _FONTS_REGISTERED = True


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
    "MEMBER": HexColor("#0D47A1"),
}

# Default design settings
DEFAULT_DESIGN = PassDesignSettings()


def generate_qr_image(
    data: str,
    box_size: int = 6,
    border: int = 2,
    transparent_bg: bool = False,
) -> Image.Image:
    """Generate a QR code PIL Image, optionally with transparent background."""
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=box_size,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)

    if transparent_bg:
        img = qr.make_image(fill_color="black", back_color="transparent")
    else:
        img = qr.make_image(fill_color="black", back_color="white")
    return img


def save_qr_image(
    data: str,
    output_path: str,
    box_size: int = 10,
    border: int = 3,
    transparent_bg: bool = False,
) -> str:
    """Save a high-resolution QR code PNG to disk."""
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    img = generate_qr_image(data, box_size=box_size, border=border, transparent_bg=transparent_bg)
    img.save(output_path, format="PNG")
    return output_path


def _set_font(c, design: PassDesignSettings, size: float, bold: bool = False):
    """Set the canvas font using the configured font family."""
    name = f"{design.font_family}-Bold" if bold else design.font_family
    c.setFont(name, size)


def _draw_field(c, x: float, y: float, label: str, value: str, design: PassDesignSettings, label_w: float = 38 * mm):
    """Draw a labelled field on the PDF canvas."""
    _set_font(c, design, 9, bold=True)
    c.setFillColor(BRAND_MUTED)
    c.drawString(x, y, label + ":")
    _set_font(c, design, 10)
    c.setFillColor(BRAND_TEXT)
    c.drawString(x + label_w, y, value or "—")


def _compute_qr_x(w: float, margin: float, qr_size: float, alignment: QRAlignment) -> float:
    """Compute QR code X position based on alignment."""
    if alignment == QRAlignment.LEFT:
        return margin + 5 * mm
    elif alignment == QRAlignment.CENTER:
        return (w - qr_size) / 2
    else:
        return w - margin - qr_size - 5 * mm


def create_pass_pdf(
    gate_pass: GatePass,
    output_path: str,
    secret: Optional[str] = None,
    design: Optional[PassDesignSettings] = None,
) -> str:
    """Generate a professional single event gate pass PDF (credit-card style on A4)."""
    register_fonts()

    if design is None:
        design = DEFAULT_DESIGN
    if design.template_path and os.path.isfile(design.template_path):
        return create_pass_pdf_on_template(gate_pass, output_path, design.template_path, secret=secret, design=design)
    if secret is None:
        secret = get_qr_secret()
    if not gate_pass.qr_payload:
        gate_pass.compute_qr_payload(secret=secret)

    qr_img = generate_qr_image(
        gate_pass.qr_payload or "",
        box_size=5,
        border=design.qr_border,
        transparent_bg=design.qr_transparent_bg,
    )
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
    _set_font(c, design, 24, bold=True)
    c.drawCentredString(w / 2, h - 18 * mm, "GATEPASSX")
    _set_font(c, design, 12)
    c.setFillColor(BRAND_GOLD)
    c.drawCentredString(w / 2, h - 27 * mm, "EVENT GATE PASS")
    _set_font(c, design, 8)
    c.setFillColor(HexColor("#AAAAAA"))
    c.drawCentredString(w / 2, h - 35 * mm, f"{gate_pass.event_name}  •  {gate_pass.event_type}")

    # --- Event name banner ---
    c.setFillColor(BRAND_ACCENT)
    c.rect(0, h - 58 * mm, w, 10 * mm, fill=1, stroke=0)
    c.setFillColor(white)
    _set_font(c, design, 11, bold=True)
    c.drawCentredString(w / 2, h - 54.5 * mm, gate_pass.event_name)

    # --- Pass ID ---
    c.setFillColor(BRAND_PRIMARY)
    _set_font(c, design, 16, bold=True)
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
    _set_font(c, design, 8, bold=True)
    c.drawCentredString(w - margin - badge_w / 2 - 6 * mm, card_top - 7.5 * mm, badge_text)

    # Detail fields
    left_x = margin + 8 * mm
    y = card_top - 16 * mm
    lh = 7 * mm

    _draw_field(c, left_x, y, "Name", gate_pass.full_name, design)
    y -= lh
    _draw_field(c, left_x, y, "ID Number", gate_pass.id_number, design)
    y -= lh
    if gate_pass.phone:
        _draw_field(c, left_x, y, "Phone", gate_pass.phone, design)
        y -= lh
    if gate_pass.email:
        _draw_field(c, left_x, y, "Email", gate_pass.email, design)
        y -= lh
    _draw_field(c, left_x, y, "Organizer", gate_pass.organizer, design)
    y -= lh
    _draw_field(c, left_x, y, "Valid", f"{gate_pass.valid_from}  →  {gate_pass.valid_to}", design)
    y -= lh
    if gate_pass.gate:
        _draw_field(c, left_x, y, "Gate", gate_pass.gate, design)
        y -= lh
    if gate_pass.table_number:
        _draw_field(c, left_x, y, "Table / Seat", gate_pass.table_number, design)
        y -= lh
    if gate_pass.group_ref:
        _draw_field(c, left_x, y, "Reference", gate_pass.group_ref, design)
        y -= lh

    # --- QR Code (configurable size + alignment) ---
    qr_size = design.qr_size_mm * mm
    qr_x = _compute_qr_x(w, margin, qr_size, design.qr_alignment)
    qr_y = card_top - card_h + 5 * mm
    c.drawImage(
        qr_reader, qr_x, qr_y,
        width=qr_size, height=qr_size,
        preserveAspectRatio=True, mask="auto",
    )

    c.setFillColor(BRAND_MUTED)
    _set_font(c, design, 7)
    c.drawCentredString(qr_x + qr_size / 2, qr_y - 4 * mm, "SCAN TO VERIFY")

    # --- Optional overlay texts ---
    if design.overlay_texts:
        overlay_y = qr_y - 10 * mm
        for ot in design.overlay_texts:
            if overlay_y < 35 * mm:
                break
            _set_font(c, design, ot.size, bold=ot.bold)
            c.setFillColor(BRAND_TEXT)
            c.drawCentredString(w / 2, overlay_y, ot.text)
            overlay_y -= (ot.size * 0.4 * mm + 2 * mm)

    # --- Footer ---
    _set_font(c, design, 7)
    c.setFillColor(BRAND_MUTED)
    c.drawString(margin, 20 * mm, f"Issued: {gate_pass.issued_at.strftime('%Y-%m-%d %H:%M UTC')} by {gate_pass.issued_by}")
    c.drawRightString(w - margin, 20 * mm, "GatePassX • Secure Event Entry")

    # Signature line
    c.setStrokeColor(HexColor("#BBBBBB"))
    c.setDash(3, 2)
    c.setLineWidth(0.5)
    c.line(margin, 30 * mm, margin + 55 * mm, 30 * mm)
    c.setDash()
    _set_font(c, design, 6)
    c.drawString(margin, 26 * mm, "Authorized Signature / Stamp")

    c.save()
    return output_path


def create_pass_pdf_on_template(
    gate_pass: GatePass,
    output_path: str,
    template_path: str,
    secret: Optional[str] = None,
    design: Optional[PassDesignSettings] = None,
) -> str:
    """Generate a gate pass PDF overlaid on a template PDF background."""
    import fitz  # PyMuPDF

    register_fonts()

    if design is None:
        design = DEFAULT_DESIGN
    if secret is None:
        secret = get_qr_secret()
    if not gate_pass.qr_payload:
        gate_pass.compute_qr_payload(secret=secret)

    # Read template to get page dimensions
    template_doc = fitz.open(template_path)
    template_page = template_doc[0]
    tw = template_page.rect.width
    th = template_page.rect.height
    template_doc.close()

    # Generate QR image
    qr_img = generate_qr_image(
        gate_pass.qr_payload or "",
        box_size=6,
        border=design.qr_border,
        transparent_bg=design.qr_transparent_bg,
    )
    qr_buf = io.BytesIO()
    qr_img.save(qr_buf, format="PNG")
    qr_buf.seek(0)
    qr_reader = ImageReader(qr_buf)

    cat_color = CATEGORY_COLORS.get(
        gate_pass.category.value if hasattr(gate_pass.category, "value") else str(gate_pass.category),
        BRAND_PRIMARY,
    )

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)

    # Create overlay PDF at template dimensions
    c = canvas.Canvas(output_path, pagesize=(tw, th))

    # Layout: big QR centered (shifted lower to clear template text cluster),
    # travel agency name as header below, Member ID + Reference as compact
    # body, overlay texts at bottom. No table/gate/badge/footer.

    def top_y(offset_from_top: float) -> float:
        """Convert offset-from-top to ReportLab y coordinate."""
        return th - offset_from_top

    center_x = tw / 2.0
    margin_x = 100.0

    # --- QR Code (centered, shifted lower to avoid template text) ---
    qr_size_mm = design.qr_size_mm
    qr_size_pts = qr_size_mm * 72.0 / 25.4
    qr_x = (tw - qr_size_pts) / 2.0
    qr_top = top_y(900)
    qr_y = qr_top - qr_size_pts

    # Draw white background behind QR for readability
    qr_pad = 12
    c.setFillColor(white)
    c.roundRect(qr_x - qr_pad, qr_y - qr_pad,
                qr_size_pts + qr_pad * 2, qr_size_pts + qr_pad * 2,
                6, fill=1, stroke=0)

    c.drawImage(
        qr_reader, qr_x, qr_y,
        width=qr_size_pts, height=qr_size_pts,
        preserveAspectRatio=True, mask="auto",
    )

    # --- Travel Agency name (header, centered below QR) ---
    header_y = qr_y - 30
    _set_font(c, design, 34, bold=True)
    c.setFillColor(BRAND_PRIMARY)
    display_name = gate_pass.full_name
    name_max_w = tw - 2 * margin_x - 20
    while c.stringWidth(display_name, f"{design.font_family}-Bold", 34) > name_max_w and len(display_name) > 15:
        display_name = display_name[:-4] + "..."
    c.drawCentredString(center_x, header_y, display_name)

    # --- Member ID + Reference (centered, compact body) ---
    body_y = header_y - 36
    body_sz = 17.0
    label_sz = 15.0

    _set_font(c, design, label_sz, bold=True)
    c.setFillColor(HexColor("#888888"))
    c.drawCentredString(center_x - 60, body_y, "Member ID:")
    _set_font(c, design, body_sz)
    c.setFillColor(BRAND_TEXT)
    c.drawCentredString(center_x + 80, body_y, gate_pass.id_number)
    body_y -= 26

    if gate_pass.group_ref:
        _set_font(c, design, label_sz, bold=True)
        c.setFillColor(HexColor("#888888"))
        c.drawCentredString(center_x - 60, body_y, "Reference:")
        _set_font(c, design, body_sz)
        c.setFillColor(BRAND_TEXT)
        c.drawCentredString(center_x + 80, body_y, gate_pass.group_ref)
        body_y -= 26

    # --- Overlay texts (centered, below metadata) ---
    if design.overlay_texts:
        body_y -= 6
        for ot in design.overlay_texts:
            if body_y < 60:
                break
            _set_font(c, design, ot.size * 1.6, bold=ot.bold)
            c.setFillColor(HexColor("#555555"))
            c.drawCentredString(center_x, body_y, ot.text)
            body_y -= (ot.size * 1.8 + 6)

    c.save()

    # Merge overlay onto template using PyMuPDF
    template_doc = fitz.open(template_path)
    overlay_doc = fitz.open(output_path)

    template_page = template_doc[0]
    overlay_page = overlay_doc[0]

    # Stamp overlay onto template
    template_page.show_pdf_page(template_page.rect, overlay_doc, 0, overlay=True)

    # Save merged result
    template_doc.save(output_path, garbage=4, deflate=True)
    template_doc.close()
    overlay_doc.close()

    return output_path


def generate_batch_pdfs(
    passes: List[GatePass],
    output_dir: str,
    secret: Optional[str] = None,
    design: Optional[PassDesignSettings] = None,
) -> List[str]:
    """Generate one PDF per pass. Returns list of written paths."""
    os.makedirs(output_dir, exist_ok=True)
    paths = []
    for p in passes:
        safe_id = p.pass_id.replace("/", "-").replace(" ", "_")
        out = os.path.join(output_dir, f"{safe_id}.pdf")
        create_pass_pdf(p, out, secret=secret, design=design)
        paths.append(out)
    return paths


def export_pdf_as_image(
    pdf_path: str,
    output_path: str,
    dpi: int = 300,
    fmt: str = "png",
    jpeg_quality: int = 95,
) -> str:
    """Render a PDF page to PNG or JPEG at the specified DPI using PyMuPDF."""
    import fitz

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    doc = fitz.open(pdf_path)
    page = doc[0]
    pix = page.get_pixmap(dpi=dpi)

    if fmt.lower() in ("jpeg", "jpg"):
        pix.save(output_path, output="jpeg", jpg_quality=jpeg_quality)
    else:
        pix.save(output_path, output="png")

    doc.close()
    return output_path


def export_batch_images(
    passes: List[GatePass],
    output_dir: str,
    secret: Optional[str] = None,
    design: Optional[PassDesignSettings] = None,
    dpi: int = 300,
    fmt: str = "png",
    jpeg_quality: int = 95,
) -> List[str]:
    """Generate PDFs then render each as PNG/JPEG. Returns list of image paths."""
    os.makedirs(output_dir, exist_ok=True)

    pdf_dir = os.path.join(output_dir, "_pdf_tmp")
    pdf_paths = generate_batch_pdfs(passes, pdf_dir, secret=secret, design=design)

    ext = "jpg" if fmt.lower() in ("jpeg", "jpg") else "png"
    image_paths = []
    for pdf_path in pdf_paths:
        base = os.path.splitext(os.path.basename(pdf_path))[0]
        img_path = os.path.join(output_dir, f"{base}.{ext}")
        export_pdf_as_image(pdf_path, img_path, dpi=dpi, fmt=fmt, jpeg_quality=jpeg_quality)
        image_paths.append(img_path)

    import shutil
    shutil.rmtree(pdf_dir, ignore_errors=True)

    return image_paths


def export_template_as_image(
    template_path: str,
    output_path: str,
    dpi: int = 300,
    fmt: str = "png",
    jpeg_quality: int = 95,
) -> str:
    """Render a template PDF to PNG or JPEG at the specified DPI."""
    return export_pdf_as_image(template_path, output_path, dpi=dpi, fmt=fmt, jpeg_quality=jpeg_quality)


def create_passes_sheet(
    passes: List[GatePass],
    output_path: str,
    secret: Optional[str] = None,
    design: Optional[PassDesignSettings] = None,
) -> str:
    """Create a summary index sheet listing all passes (A4)."""
    if not passes:
        raise ValueError("No passes provided")

    register_fonts()
    if design is None:
        design = DEFAULT_DESIGN

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
    _set_font(c, design, 16, bold=True)
    c.drawCentredString(w / 2, h - 14 * mm, "GATEPASSX — Batch Summary")
    _set_font(c, design, 9)
    c.setFillColor(BRAND_GOLD)
    c.drawCentredString(w / 2, h - 22 * mm, f"{passes[0].event_name}")

    c.setFillColor(BRAND_TEXT)
    _set_font(c, design, 9)
    y = h - 38 * mm
    c.drawString(15 * mm, y, f"Total passes: {len(passes)}   Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M UTC')}")
    y -= 4 * mm

    # Table header
    c.setStrokeColor(BRAND_PRIMARY)
    c.setLineWidth(0.5)
    c.line(15 * mm, y, w - 15 * mm, y)
    y -= 5 * mm
    _set_font(c, design, 8, bold=True)
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

    _set_font(c, design, 8)
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
    generate_batch_pdfs(passes, ind_dir, secret=secret, design=design)
    return output_path


# ── Lock / Manifest ─────────────────────────────────────────────────────────


def lock_input_file(input_path: str, output_dir: str, pass_count: int) -> PassManifest:
    """Create a .lock manifest for the input file after successful generation."""
    manifest = PassManifest(
        input_file=str(input_path),
        input_hash=PassManifest.hash_file(input_path),
        output_dir=str(output_dir),
        pass_count=pass_count,
    )
    manifest.write_lock()
    return manifest


def check_input_lock(input_path: str) -> tuple[Optional[PassManifest], bool]:
    """Check if the input file is locked and whether it has been altered.

    Returns (manifest_or_none, is_intact).
    - (None, True)       → no lock exists, file is unlocked
    - (manifest, True)   → locked, file matches the generation hash
    - (manifest, False)  → locked, file has been ALTERED since generation
    """
    manifest = PassManifest.read_lock(input_path)
    if manifest is None:
        return None, True
    current_hash = PassManifest.hash_file(input_path)
    return manifest, current_hash == manifest.input_hash


def unlock_input_file(input_path: str) -> bool:
    """Remove the .lock file for the given input. Returns True if a lock was removed."""
    lock_path = input_path + ".lock"
    if os.path.isfile(lock_path):
        os.remove(lock_path)
        return True
    return False
