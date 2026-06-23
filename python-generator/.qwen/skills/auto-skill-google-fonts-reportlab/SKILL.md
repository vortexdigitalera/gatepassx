---
name: google-fonts-reportlab
description: Embed Google Fonts in ReportLab PDFs with bold variants, transparent QR codes, configurable design settings, overlay content on template PDFs via PyMuPDF, high-res PNG/JPEG export, XLSX batch input, and SHA-256 lock manifests to prevent post-print data alteration
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

## High-resolution PNG/JPEG export from PDFs (PyMuPDF)

PyMuPDF's `page.get_pixmap(dpi=N)` renders any PDF page to a raster image at arbitrary DPI. This is the cleanest way to produce print-quality images from PDF output.

```python
import fitz  # PyMuPDF

def export_pdf_as_image(pdf_path, output_path, dpi=300, fmt="png", jpeg_quality=95):
    doc = fitz.open(pdf_path)
    page = doc[0]
    pix = page.get_pixmap(dpi=dpi)
    if fmt.lower() in ("jpeg", "jpg"):
        pix.save(output_path, output="jpeg", jpg_quality=jpeg_quality)
    else:
        pix.save(output_path, output="png")
    doc.close()
    return output_path
```

### DPI reference (A4 page)

| DPI | Pixels | Use case |
|-----|--------|----------|
| 150 | 1240×1754 | Screen preview |
| 300 | 2481×3508 | Standard print |
| 600 | 4961×7016 | High-quality print |

### Batch image export pattern

Generate PDFs to a temp directory, render each to images, then clean up:

```python
import os, shutil

def export_batch_images(passes, output_dir, dpi=300, fmt="png"):
    os.makedirs(output_dir, exist_ok=True)
    pdf_dir = os.path.join(output_dir, "_pdf_tmp")
    pdf_paths = generate_batch_pdfs(passes, pdf_dir)  # your PDF generator
    ext = "jpg" if fmt.lower() in ("jpeg", "jpg") else "png"
    image_paths = []
    for pdf_path in pdf_paths:
        base = os.path.splitext(os.path.basename(pdf_path))[0]
        img_path = os.path.join(output_dir, f"{base}.{ext}")
        export_pdf_as_image(pdf_path, img_path, dpi=dpi, fmt=fmt)
        image_paths.append(img_path)
    shutil.rmtree(pdf_dir, ignore_errors=True)
    return image_paths
```

> **Gotcha:** PIL raises `DecompressionBombWarning` for images >89M pixels (~600 DPI on large pages). This is a warning, not an error — the image is still written correctly. For very large template PDFs at 600 DPI, expect this warning.

## XLSX batch input (openpyxl)

### Reading XLSX as a list of dicts

```python
from openpyxl import load_workbook

wb = load_workbook("data.xlsx", read_only=True, data_only=True)
ws = wb.active
rows_iter = ws.iter_rows(values_only=True)
headers = [str(c).strip() if c is not None else "" for c in next(rows_iter)]
for cells in rows_iter:
    row = {headers[i]: cells[i] for i in range(min(len(headers), len(cells))) if headers[i]}
    if not any(row.values()):  # skip empty rows
        continue
    # process row dict
wb.close()
```

### Critical gotcha: openpyxl datetime handling

openpyxl returns `datetime.datetime` objects for date cells, **not** strings. If you naively stringify all cells first and then try to parse dates, the `isinstance(v, datetime)` check will never match. The correct order is:

1. **First** — coerce date/datetime columns while values still have native types
2. **Then** — stringify everything else

```python
def coerce_xlsx_row(row: dict) -> dict:
    # Step 1: Handle datetime columns FIRST (before stringifying)
    if "valid_from" in row and row["valid_from"]:
        v = row["valid_from"]
        if isinstance(v, datetime):
            row["valid_from"] = v.date()
        elif not isinstance(v, date):
            row["valid_from"] = date.fromisoformat(str(v)[:10])
    # ... same for valid_to, issued_at, etc.

    # Step 2: Handle enum columns
    if "category" in row and row["category"]:
        row["category"] = PassCategory(str(row["category"]).upper())

    # Step 3: NOW stringify remaining non-special values
    for key in list(row.keys()):
        v = row[key]
        if v is None:
            row[key] = ""
        elif isinstance(v, (date, datetime, PassCategory, EventType)):
            pass  # keep typed values
        elif not isinstance(v, str):
            row[key] = str(v)
    return row
```

### Generating XLSX templates

```python
from openpyxl import Workbook

wb = Workbook()
ws = wb.active
ws.title = "Passes"
ws.append(["pass_id", "full_name", "id_number", ...])  # headers
ws.append(["GPX-001", "Jane Doe", "REG-001", ...])      # sample row
wb.save("template.xlsx")
```

## SHA-256 lock manifests — prevent data alteration after printing

When batch-generating PDFs from a data file (CSV/JSON/XLSX), you need to lock the source after printing to prevent silent edits that diverge from what was actually printed. A `.lock` manifest file with a SHA-256 hash solves this.

### Manifest model (Pydantic)

```python
import hashlib
from datetime import datetime
from pathlib import Path
from pydantic import BaseModel, Field

class PassManifest(BaseModel):
    input_file: str
    input_hash: str           # SHA-256 of the input at generation time
    output_dir: str
    pass_count: int
    generated_at: datetime = Field(default_factory=datetime.utcnow)

    @property
    def lock_path(self) -> str:
        return self.input_file + ".lock"

    def write_lock(self) -> str:
        Path(self.lock_path).write_text(self.model_dump_json(indent=2))
        return self.lock_path

    @classmethod
    def read_lock(cls, input_file: str):
        lock = Path(input_file + ".lock")
        if not lock.exists():
            return None
        return cls.model_validate_json(lock.read_text())

    @staticmethod
    def hash_file(path: str) -> str:
        h = hashlib.sha256()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                h.update(chunk)
        return h.hexdigest()
```

### Integration pattern in CLI (click)

```python
# At the START of generate: check for existing lock
manifest, intact = check_input_lock(str(input_path))
if manifest is not None and not intact:
    click.echo(f"✗ LOCKED: {input_path} has been altered since last generation.")
    if not force:
        sys.exit(1)

# ... run generation ...

# At the END of generate: auto-lock
if not no_lock:
    m = lock_input_file(str(input_path), str(output_dir), len(passes))
    click.echo(f"🔒 Locked {input_path.name} ({len(passes)} passes)")
```

### CLI commands

- `lock <file>` — manually create a `.lock` manifest
- `unlock <file>` — remove the `.lock` file to allow regeneration
- `status <file>` — show lock state, hash, and whether data matches

### Gotchas

- **Lock file lives next to the input** (`data.csv.lock`), not in the output dir — this makes it visible and hard to miss
- **`--force` bypasses the lock** for intentional re-generation after edits
- **`--no-lock` skips locking** for development/iteration workflows
- **Hash is of the raw file bytes**, not the parsed data — this catches any edit including whitespace, encoding, or column reordering
