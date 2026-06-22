#!/usr/bin/env bash
# Setup Python venv for the generator in a high-space location (/tmp)
# This avoids bloating the main workspace with venv files.

set -euo pipefail

VENV_ROOT="${GATEPASSX_PYTHON_VENV:-/tmp/gatepassx-builds/python/venv}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/python-generator"

echo "==> Creating venv at: $VENV_ROOT"
python3 -m venv "$VENV_ROOT"

source "$VENV_ROOT/bin/activate"

echo "==> Installing requirements..."
pip install --upgrade pip
pip install -r "$PROJECT_DIR/requirements.txt"

echo ""
echo "==> Done. Activate with:"
echo "    source $VENV_ROOT/bin/activate"
echo ""
echo "Then from the python-generator directory:"
echo "    python -m gatepass_generator --help"
echo ""
echo "To use a different location set: GATEPASSX_PYTHON_VENV=/path/to/venv"
