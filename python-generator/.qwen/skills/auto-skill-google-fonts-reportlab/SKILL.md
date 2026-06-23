---
name: google-fonts-reportlab
description: Embed Google Fonts in ReportLab PDFs with bold variants, transparent QR codes, configurable design settings, and overlay content on template PDFs via PyMuPDF
source: auto-skill
extracted_at: '2026-06-23T09:15:25.847Z'
---

# Embedding Google Fonts in ReportLab PDFs

## Problem
ReportLab requires TTF/TTC font files on disk. Google Fonts CSS API serves woff2 — unusable directly. Variable fonts need special handling for bold/italic variants.

## Step 1 — Download TTF from the GitHub repo (not the CSS API)

Google Fonts hosts the raw TTF sources at:
```
https://github.com/google/fonts/raw/main/ofl/<fontname>/<FontFile>.ttf
```

Example for Bricolage Grotesque (variable font with opsz, wdth, wght axes):
```bash
curl -L -o BricolageGrotesque-Variable.ttf \
  "https://github.com/google/fonts/raw/main/ofl/bricolagegrotesque/BricolageGrotesque%5Bopsz%2Cwdth%2Cwght%5D.ttf"
```

The URL-encoded brackets `%5B` / `%5D` and commas `%2C` are required.

## Step 2 — Create static Bold instance (when fontTools.instancer is unavailable)

`fontTools.instancer.instantiateVariableFont` is the proper way, but it may not be installed. Fallback: strip variable tables after setting default axis values:

```python
from fontTools.ttLib import TTFont

def make_static(src_path, out_path, target_wght=400):
    font = TTFont(src_path)
    fvar = font['fvar']
    for axis in fvar.axes:
        if axis.axisTag == 'wght':
            axis.defaultValue = target_wght
        elif axis.axisTag == 'opsz':
            axis.defaultValue = 24
        elif axis.axisTag == 'wdth':
            axis.defaultValue = 100
    for table in ['fvar', 'STAT', 'gvar', 'avar', 'cvar']:
        if table in font:
            del font[table]
    font.save(out_path)

make_static('Variable.ttf', 'Regular.ttf', 400)
make_static('Variable.ttf', 'Bold.ttf', 700)
```

> **Caveat:** This does NOT truly instantiate bold outlines — it just changes metadata defaults. The glyph shapes remain at the variable font's default. For true bold instantiation, `fontTools.instancer` (with `scipy` dependency) is required. In practice, ReportLab renders the variable font at its default weight and the "Bold" file looks identical; differentiation comes from using the font family registration and size adjustments.

## Step 3 — Register with ReportLab

```python
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

pdfmetrics.registerFont(TTFont("MyFont", "fonts/MyFont-Variable.ttf"))
pdfmetrics.registerFont(TTFont("MyFont-Bold", "fonts/MyFont-Bold.ttf"))
pdfmetrics.registerFontFamily("MyFont", normal="MyFont", bold="MyFont-Bold")
```

Then use `c.setFont("MyFont", 12)` for regular and `c.setFont("MyFont-Bold", 12)` for bold.

## Transparent QR codes (no white background)

The `qrcode` library supports transparent backgrounds natively:

```python
import qrcode
qr = qrcode.QRCode(version=1, box_size=5, border=0)  # border=0 removes quiet zone
qr.add_data(payload)
qr.make(fit=True)
img = qr.make_image(fill_color="black", back_color="transparent")  # RGBA output
```

When embedding in ReportLab PDFs, use `mask="auto"` on `drawImage` so the transparent areas show through:
```python
c.drawImage(qr_reader, x, y, width=size, height=size, preserveAspectRatio=True, mask="auto")
```

## Configurable design settings pattern

Use a Pydantic model to bundle all design knobs and pass it through the generator:

```python
class PassDesignSettings(BaseModel):
    qr_size_mm: float = 40.0
    qr_alignment: QRAlignment = QRAlignment.RIGHT  # left | center | right
    qr_transparent_bg: bool = True
    qr_border: int = 0
    overlay_texts: List[OverlayText] = []
    font_family: str = "BricolageGrotesque"
```

CLI flags (`click`) map to these: `--qr-size`, `--qr-align`, `--qr-transparent`, `--overlay-text` (repeatable), `--text-size` (repeatable, paired with overlay-text by index).

## Overlaying content on a pre-designed template PDF (PyMuPDF + ReportLab)

When a pre-designed template PDF exists (e.g. branded gate pass with logo, headers, background images), you can overlay dynamic data on top of it rather than recreating the design in code.

### Step A — Analyze the template with PyMuPDF

Extract page dimensions and text positions to find available zones for overlay content:

```python
import fitz  # PyMuPDF

doc = fitz.open("template.pdf")
page = doc[0]
tw, th = page.rect.width, page.rect.height  # page size in points

# Extract text with positions to find where template content ends
blocks = page.get_text("dict")["blocks"]
for block in blocks:
    if "lines" in block:
        for line in block["lines"]:
            for span in line["spans"]:
                text = span["text"].strip()
                if text:
                    x, y = span["bbox"][0], span["bbox"][1]
                    print(f"  [{x:.0f},{y:.0f}] sz={span['size']:.1f}: {text}")
    elif "image" in block:
        x, y, w, h = block["bbox"]
        print(f"  [IMG {x:.0f},{y:.0f} {w:.0f}x{h:.0f}]")
doc.close()
```

This tells you: where template text/images end, and where overlay content should begin.

### Step B — Create an overlay PDF at the template's exact page size

Use ReportLab to draw overlay content (text, QR code, badges) at the template's dimensions:

```python
from reportlab.pdfgen import canvas

c = canvas.Canvas("overlay.pdf", pagesize=(tw, th))

# Coordinate converter: template analysis uses top-origin,
# ReportLab uses bottom-origin
def top_y(offset_from_top):
    return th - offset_from_top

# Draw content below template's existing header area
c.setFont("MyFont", 24)
c.drawString(140, top_y(940), "Dynamic Name Here")
# ... more fields, QR code, etc.
c.save()
```

> **Key insight:** ReportLab's y=0 is at the bottom. The `top_y()` helper converts top-down coordinates (matching PyMuPDF's `bbox` output) to ReportLab's bottom-up system.

### Step C — Merge overlay onto template

```python
import fitz

template_doc = fitz.open("template.pdf")
overlay_doc = fitz.open("overlay.pdf")

template_page = template_doc[0]
# Stamp overlay onto template (overlay=True puts it on top)
template_page.show_pdf_page(template_page.rect, overlay_doc, 0, overlay=True)

# Save merged result to the output path (overwrites overlay.pdf)
template_doc.save("final_pass.pdf", garbage=4, deflate=True)
template_doc.close()
overlay_doc.close()
```

### Gotchas

- **Font size scaling:** Template pages are often larger than A4 (e.g. 1097×1536 pts ≈ 387×542mm). Font sizes need to be proportionally larger (~2× the A4 sizes). Multiply overlay text sizes by the ratio of template height to A4 height.
- **`garbage=4, deflate=True`:** Important for keeping merged PDF file size reasonable — removes unused objects and compresses streams.
- **`overlay=True`:** Critical — without it, the template content goes on top and hides your overlay data.
- **The output path:** The simplest pattern is to write the overlay to the final output path, then have `template_doc.save()` overwrite it with the merged result.
