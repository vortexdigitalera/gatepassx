#!/usr/bin/env bash
# Helper to build/run the Flutter app using high-disk-space location (/tmp)
# This keeps the main /workspaces volume clean.
#
# Usage examples:
#   ./scripts/build-flutter.sh build apk
#   ./scripts/build-flutter.sh build web
#   ./scripts/build-flutter.sh run
#   ./scripts/build-flutter.sh clean

set -euo pipefail

BUILD_ROOT="${GATEPASSX_FLUTTER_BUILD_DIR:-/tmp/gatepassx-builds/flutter}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/mobile"

mkdir -p "$BUILD_ROOT"

cd "$PROJECT_DIR"

echo "==> Flutter project: $PROJECT_DIR"
echo "==> Build dir     : $BUILD_ROOT"
echo "==> Disk (tmp)    :"
df -h /tmp | tail -1

case "${1:-help}" in
  clean)
    echo "==> flutter clean (also removing build dir)"
    flutter clean
    rm -rf "$BUILD_ROOT"
    ;;
  build)
    shift
    echo "==> flutter build $* --build-dir $BUILD_ROOT"
    flutter build "$@" --build-dir "$BUILD_ROOT"
    ;;
  run)
    shift
    echo "==> flutter run --build-dir $BUILD_ROOT $*"
    flutter run --build-dir "$BUILD_ROOT" "$@"
    ;;
  analyze|test|pub)
    # These don't produce heavy build artifacts
    flutter "$@"
    ;;
  *)
    echo "Usage: $0 {clean|build <target>|run [args]|analyze|test|pub get}"
    echo ""
    echo "Environment override: GATEPASSX_FLUTTER_BUILD_DIR=/some/other/path"
    exit 1
    ;;
esac
