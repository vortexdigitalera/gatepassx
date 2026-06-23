GatePassX — Dinner & Event Gate Pass CLI

Standalone CLI tool for generating printable event gate passes with QR codes.

## Install
  pip install -r requirements.txt

## Commands

  gatepassx --help                          # Show all commands
  gatepassx template -o guests.json         # Create a data template
  gatepassx new -o pass.json                # Create a pass interactively
  gatepassx generate -i data.json -o out/   # Generate PDFs
  gatepassx generate -i data.csv -o out/ --sheet --qr-only  # Batch PDFs + QRs
  gatepassx qr -i pass.json -o qr.png       # Single QR code image
  gatepassx validate pass.json              # Validate a pass file
  gatepassx scan '<qr_payload>'             # Verify a QR payload string
  gatepassx info -i data.json               # Show statistics

## Environment
  GATEPASSX_QR_SECRET=your-secret           # Set for signed QR codes

## Notes
- PDFs are generated in the output directory.
- Works with the Flutter mobile app for JSON data interchange.
- Supports CSV, JSON, and YAML input formats.
