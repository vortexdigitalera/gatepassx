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

# Redirect all heavy build caches to fast /tmp storage
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-/tmp/.gradle}"
export PUB_CACHE="${PUB_CACHE:-/tmp/.pub-cache}"

BUILD_ROOT="${GATEPASSX_FLUTTER_BUILD_DIR:-/tmp/gatepassx-builds/flutter}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/mobile"

mkdir -p "$GRADLE_USER_HOME" "$PUB_CACHE"

cd "$PROJECT_DIR"

echo "==> Flutter project: $PROJECT_DIR"
echo "==> Gradle cache  : $GRADLE_USER_HOME"
echo "==> Pub cache     : $PUB_CACHE"
echo "==> Disk (tmp)    :"
df -h /tmp | tail -1
echo "==> Note: flutter build outputs go to standard build/ (caches redirected to /tmp)"

case "${1:-help}" in
  clean)
    echo "==> flutter clean (also removing temp caches)"
    flutter clean
    rm -rf "$GRADLE_USER_HOME" "$PUB_CACHE" 2>/dev/null || true
    ;;
  build)
    shift
    echo "==> flutter build $* (Gradle/Pub caches in /tmp)"
    flutter build "$@"
    ;;
  run)
    shift
    echo "==> flutter run (caches in /tmp) $*"
    # --build-dir is valid for run
    flutter run --build-dir "/tmp/gatepassx-builds/flutter-run" "$@"
    ;;
  analyze|test|pub)
    # These don't produce heavy build artifacts
    flutter "$@"
    ;;
  *)
    echo "Usage: $0 {clean|build <target>|run [args]|analyze|test|pub get}"
    echo ""
    echo "Heavy caches (Gradle + Pub) are forced to /tmp."
    echo "flutter build outputs use the standard 'build/' directory inside the project."
    echo "Override caches with: GRADLE_USER_HOME=... PUB_CACHE=... "
    exit 1
    ;;
esac
