GatePassX Python Generator (AHUON)

This is a standalone packaging of the gate pass PDF + QR generator tool.

## Requirements
pip install -r requirements.txt

## Usage Examples

Generate passes from CSV:
  python -m gatepass_generator generate -i sample_data/pilgrims.csv -o passes/ --sheet

Create a new pass interactively:
  python -m gatepass_generator new-pass

Validate a pass:
  python -m gatepass_generator validate path/to/pass.json

## Notes
- Output PDFs will be created in the specified directory.
- The tool is designed to work together with the Flutter mobile app for data exchange via JSON.
