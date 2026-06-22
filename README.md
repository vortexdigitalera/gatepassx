# GatePassX — AHUON Gate Pass Management System

**Digital Gate Pass System for the Association for Hajj and Umrah Operators of Nigeria (AHUON)**

GatePassX enables secure, efficient issuance, validation, and tracking of gate passes for pilgrims, staff, operators, visitors, and vehicles during Hajj and Umrah operations.

## Project Goals
- Streamline pilgrim and personnel movement at assembly points, departure gates, airports, and camps.
- Provide tamper-evident digital passes with QR codes.
- Support both batch high-quality PDF generation (for printing) and on-the-ground mobile operations.
- Work reliably in low-connectivity environments common in operations.

## Components

### 1. Python Generator (`python-generator/`)
A standalone Python library + CLI for:
- Generating professional printable gate passes as PDFs (single or batch).
- Embedding cryptographically verifiable QR codes.
- Importing pilgrim/operator data from CSV/JSON/Excel.
- Validation, signing, and reporting.
- Useful for headquarters / back-office staff to prepare large volumes of passes.

**Tech**: Python 3.10+, Pillow, qrcode, reportlab/fpdf2, Pydantic, Click.

### 2. Flutter Mobile App (`mobile/`)
Cross-platform mobile application for field teams and security:
- Issue passes on the spot (form entry → instant QR).
- Scan & validate gate passes (camera scanner + offline validation).
- View, search, and manage active/invalidated passes.
- Log entries/exits with timestamps and notes.
- Local-first storage (works offline) with optional sync/export.
- Role-aware UI (Security, Operator/Issuer, Admin).

**Tech**: Flutter 3+, Dart, sqflite/hive for storage, qr_code_scanner / mobile_scanner, pdf generation, share_plus, etc.

## Key Features (MVP Scope)
- Pass data model tailored for AHUON operations (Hajj/Umrah, operator affiliation, passport/NIN, group/flight info, gate assignment).
- Unique pass ID + HMAC or simple signature for verification.
- QR payload includes pass metadata + integrity hash.
- Entry/exit audit log.
- Batch PDF printing support (A4 sheets or individual cards).
- Sample data for testing.
- Export/Import passes as JSON bundles (shared between generator and app).

## Directory Structure
```
gatepassx/
├── README.md
├── scripts/
│   ├── build-flutter.sh       # Always builds to /tmp/gatepassx-builds
│   └── setup-python-venv.sh   # Creates venv under /tmp
├── python-generator/
│   ├── gatepass_generator/
│   │   ├── __init__.py
│   │   ├── models.py
│   │   ├── generator.py      # PDF + QR generation
│   │   ├── cli.py
│   │   └── utils.py
│   ├── sample_data/
│   ├── tests/
│   └── requirements.txt
├── mobile/                   # Flutter app (source only)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   └── ...
├── sample_data/
├── shared/
├── docs/
└── .gitignore
```

**Note:** Build outputs intentionally live under `/tmp/gatepassx-builds` (see Disk section).
```

## Getting Started

### Prerequisites
- Python 3.12+
- Flutter SDK (3.22+)
- For mobile development: Android Studio / Xcode (for full builds)

### ⚠️ Disk Space & Build Location Strategy

**Important on this codespace / limited environments:**

- **Source** lives in `/workspaces/gatepassx` (small, git-tracked).
- **Build artifacts** (especially Flutter Gradle, caches, APKs, web builds) should **never** go into the main workspace.
- **Best location**: `/tmp/gatepassx-builds` — separate 118 GB volume with ~109 GB free.
- The main volumes are much tighter (one is already ~79% used).

We provide helper scripts that automatically target the high-capacity location.

**Recommended setup commands:**

```bash
# Python (recommended - venv in /tmp)
./scripts/setup-python-venv.sh
# Then activate:
source /tmp/gatepassx-builds/python/venv/bin/activate

# Flutter builds/runs (always use the helper or --build-dir)
./scripts/build-flutter.sh pub get
./scripts/build-flutter.sh build web          # or apk, aab, etc.
./scripts/build-flutter.sh run -d chrome
./scripts/build-flutter.sh clean
```

You can override locations:
```bash
export GATEPASSX_FLUTTER_BUILD_DIR=/some/other/fast/volume
export GATEPASSX_PYTHON_VENV=/tmp/my-venv
export GRADLE_USER_HOME=/tmp/.gradle
export PUB_CACHE=/tmp/.pub-cache
```

Manual equivalent (Flutter):
```bash
cd mobile
flutter build web --build-dir /tmp/gatepassx-builds/flutter-web
```

### Releasing (GitHub Actions)

Push a version tag to automatically build and publish:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or go to **Actions → "Build and Release" → Run workflow** (manual).

The workflow will produce and attach to the GitHub Release:

- `gatepassx-android-vX.Y.Z.apk` — Flutter Android release build (all caches built in /tmp on the runner)
- `gatepassx-python-generator-vX.Y.Z.zip` — Self-contained Python generator tool (with requirements + samples)

See [.github/workflows/release.yml](.github/workflows/release.yml) for details. All CI builds also force Gradle + Pub + Flutter build outputs into temp storage.

### Python Generator
```bash
# After activating the /tmp venv (see above)
cd python-generator
python -m gatepass_generator --help

# Example generation
python -m gatepass_generator generate -i ../sample_data/pilgrims.csv -o /tmp/passes --sheet
```

### Flutter App
Use the helper script above for best results.

Direct (when you want full control):
```bash
cd mobile
flutter pub get
flutter run --build-dir /tmp/gatepassx-builds/flutter-run
```

## Data Model Highlights (Pass)
- `pass_id`: string (unique, e.g. AHUON-HAJJ-2026-000123)
- `category`: PILGRIM | STAFF | VEHICLE | VISITOR | VIP
- `full_name`
- `id_number` (Passport / NIN / License)
- `phone`
- `operator`: AHUON member tour operator name
- `trip_type`: HAJJ | UMRAH
- `valid_from`, `valid_to`
- `gate` / `checkpoint`
- `group_ref` or `flight_ref`
- `issued_at`, `issued_by`
- `qr_payload`: the encoded verifiable data
- Optional: photo reference, vehicle_plate

## Verification Flow
1. Pass issued (Python batch or Flutter on-device).
2. QR contains JSON + integrity signature.
3. Scanner decodes, recomputes hash, checks validity dates, optionally checks against local allow-list.
4. Log entry action (offline queue).

## Current Status (resumed build)
✅ Python generator (models, PDF+QR via reportlab, CLI, batch + JSON/CSV import)
✅ Flutter app (Issue form, QR display with qr_flutter, list, import/export JSON, simulated + mobile scanner entry, local persistence, dashboard, logs)
✅ Compatible data interchange between Python and Flutter via JSON/QR payload
✅ Sample data + generated example PDFs

## Next Steps / Roadmap (from previous chat)
- Core models + Python PDF generator [done]
- Flutter project scaffold + basic navigation [done]
- Pass issuance form + QR display [done]
- Scanner + validation logic [basic + demo]
- Persistence + sample data + import/export [done]
- Polish, theming with AHUON branding (green/white), reports, real PDF export in app, better offline sync, auth

## Contributing
This project is developed for AHUON operational needs. Follow standard PR flow.

## License
Internal / TBD for AHUON use.

---

Built with ❤️ for seamless Hajj & Umrah experiences across Nigeria.
