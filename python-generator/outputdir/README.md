# GatePassX — AHUON Post Hajj Dinner 2026

## Event Details

| Field        | Value                                         |
|--------------|-----------------------------------------------|
| Event        | AHUON Post Hajj Dinner 2026                   |
| Date         | 28 June 2026                                  |
| Organization | Association for Hajj & Umrah Operators of Nigeria |
| Zone         | KANO ZONE                                     |
| Category     | MEMBER                                        |

## Quick Start

```bash
pip install -r requirements.txt

# Generate passes using the template
python3 -m app generate \
  -i operators_sample.csv \
  -o ./passes \
  --template template.pdf \
  --qr-size 130 --qr-align center --qr-border 0 --qr-transparent \
  --overlay-text "28 June 2026" --text-size 11 \
  --overlay-text "AHUON Post Hajj Dinner" --text-size 9

# Generate all 98 passes from the full CSV
python3 -m app generate -i operators.csv -o ./passes --template template.pdf --qr-size 130

# Batch summary sheet
python3 -m app generate -i operators_sample.csv -o ./passes --sheet

# QR-only PNGs
python3 -m app generate -i operators_sample.csv -o ./passes --qr-only

# See file stats
python3 -m app info -i operators_sample.csv
```

## CLI Options (generate)

| Option              | Default    | Description                              |
|---------------------|------------|------------------------------------------|
| `--template`        | (none)     | Template PDF to use as background        |
| `--qr-size`         | 40         | QR code size in mm                       |
| `--qr-align`        | right      | QR alignment: left / center / right      |
| `--qr-border`       | 0          | QR quiet-zone border (0 = no white edge) |
| `--qr-transparent`  | on         | Transparent QR background                |
| `--overlay-text`    | (none)     | Extra text line (repeatable)             |
| `--text-size`       | 10         | Font size per overlay text (repeatable)  |
| `--sheet`           | off        | Also produce batch summary PDF           |
| `--qr-only`         | off        | QR PNGs only, no PDFs                    |

## Files

- `template.pdf` — pre-designed pass background (KANO ZONE / AHUON branding)
- `operators_sample.csv` — 1 member entry (sample)
- `operators_sample.json` — same data in JSON format
- `design_settings.json` — saved QR/layout config
- `app/` — generator package (source + Bricolage Grotesque fonts)

## Font

**Bricolage Grotesque** (Google Fonts) — embedded in `app/fonts/`.
