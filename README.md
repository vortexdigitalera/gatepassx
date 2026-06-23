# GatePassX — Dinner & Event Gate Pass Scanner and QR Generator

**Digital Gate Pass System for Events — Dinners, Galas, Conferences, Weddings, Concerts, and more.**

GatePassX enables secure, efficient issuance, validation, and tracking of gate passes for guests, VIPs, staff, speakers, performers, media, and vendors at any event.

## Features
- Tamper-evident digital passes with cryptographically signed QR codes
- Professional printable PDF passes (single or batch)
- Mobile app for on-the-spot issuance, scanning, and validation
- Works offline — ideal for venues with poor connectivity
- Table/seat assignments for dinner and gala events
- Role-aware categories: Guest, VIP, Staff, Speaker, Performer, Media, Vendor, Exhibitor
- Compatible data interchange between Python CLI and Flutter app via JSON

## Components

### 1. Python CLI (`python-generator/`)
A standalone CLI tool for:
- Generating professional printable PDFs with QR codes (single or batch)
- Creating standalone QR code images
- Importing guest data from CSV/JSON/YAML
- Validating QR signatures
- Generating data templates for bulk import
- Viewing pass statistics

**Tech**: Python 3.10+, reportlab, qrcode, Pillow, Pydantic, Click.

### 2. Flutter Mobile App (`mobile/`)
Cross-platform mobile application for event teams and security:
- Issue passes on the spot (form → instant QR)
- Scan & validate gate passes (camera scanner + offline validation)
- View, search, and manage active/expired passes
- Log entries/exits with timestamps
- Local-first storage (works offline)
- Import/export JSON for interchange with CLI

**Tech**: Flutter 3+, Dart, mobile_scanner, qr_flutter, shared_preferences.

## CLI Quick Start

```bash
# Set up virtual environment
./scripts/setup-python-venv.sh
source /tmp/gatepassx-builds/python/venv/bin/activate

# See all commands
gatepassx --help

# Generate a data template
gatepassx template -o guests.json          # JSON format
gatepassx template -o guests.csv --format csv  # CSV format

# Create a pass interactively
gatepassx new -o pass.json

# Generate PDFs from data file
gatepassx generate -i guests.json -o ./passes
gatepassx generate -i guests.csv -o ./passes --sheet    # with summary sheet
gatepassx generate -i guests.json -o ./qr --qr-only     # QR images only

# Generate a single QR code from a pass JSON
gatepassx qr -i pass.json -o qr.png

# Validate a pass file
gatepassx validate pass.json

# Scan/verify a QR payload string
gatepassx scan '{"pid":"GPX-DINNER-2026-000001","nm":"Chioma Okafor",...}'

# View data statistics
gatepassx info -i guests.json
```

### CLI Commands

| Command | Description |
|---------|-------------|
| `generate` | Generate PDF passes or QR images from a data file |
| `new` | Interactively create a new pass (outputs JSON) |
| `validate` | Validate and display details of a pass JSON file |
| `scan` | Scan/verify a QR payload string from the terminal |
| `qr` | Generate a standalone QR code PNG from a pass JSON |
| `template` | Generate a sample data template for bulk import |
| `info` | Show statistics of a pass data file |

## Data Model (Pass)

| Field | Description |
|-------|-------------|
| `pass_id` | Unique ID (e.g. `GPX-DINNER-2026-000001`) |
| `event_name` | Event name |
| `event_type` | DINNER, GALA, CONFERENCE, WEDDING, CONCERT, FESTIVAL, EXHIBITION, CORPORATE, PRIVATE_PARTY, OTHER |
| `category` | GUEST, VIP, STAFF, SPEAKER, PERFORMER, MEDIA, VENDOR, EXHIBITOR |
| `full_name` | Guest name |
| `id_number` | ID / registration number |
| `phone` | Phone number |
| `email` | Email address |
| `organizer` | Event organizer |
| `valid_from` / `valid_to` | Validity dates |
| `gate` | Entrance gate / checkpoint |
| `table_number` | Table or seat assignment |
| `group_ref` | Group / booking / invitation reference |
| `qr_payload` | Signed QR data (computed) |

## Verification Flow

1. Pass issued (CLI batch or mobile on-device)
2. QR contains JSON + HMAC integrity signature
3. Scanner decodes, recomputes hash, checks validity dates
4. Entry/exit logged with timestamp

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `GATEPASSX_QR_SECRET` | HMAC secret for QR signing (must match across CLI and mobile) |

Set via environment or `--dart-define=GATEPASSX_QR_SECRET=...` for Flutter builds.

## Directory Structure

```
gatepassx/
├── python-generator/       # CLI tool
│   ├── gatepass_generator/
│   │   ├── models.py       # Data models
│   │   ├── generator.py    # PDF + QR generation
│   │   ├── cli.py          # CLI commands
│   │   └── utils.py        # Verification helpers
│   └── requirements.txt
├── mobile/                 # Flutter app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── screens/
│   │   └── services/
│   └── pubspec.yaml
├── sample_data/            # Sample guest data
├── scripts/                # Build helpers
├── .github/workflows/      # CI/CD
└── docs/
```

## Releasing

```bash
git tag v1.0.0 && git push origin v1.0.0
```

Produces Android APK and Python CLI zip via GitHub Actions.

## License

Internal / TBD.
