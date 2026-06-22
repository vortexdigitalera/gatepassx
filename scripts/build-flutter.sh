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

mkdir -p "$BUILD_ROOT" "$GRADLE_USER_HOME" "$PUB_CACHE"

cd "$PROJECT_DIR"

echo "==> Flutter project: $PROJECT_DIR"
echo "==> Build dir     : $BUILD_ROOT"
echo "==> Gradle cache  : $GRADLE_USER_HOME"
echo "==> Pub cache     : $PUB_CACHE"
echo "==> Disk (tmp)    :"
df -h /tmp | tail -1

case "${1:-help}" in
  clean)
    echo "==> flutter clean (also removing build dir + temp caches)"
    flutter clean
    rm -rf "$BUILD_ROOT" "$GRADLE_USER_HOME" "$PUB_CACHE" 2>/dev/null || true
    ;;
  build)
    shift
    echo "==> flutter build $* --build-dir $BUILD_ROOT (caches in /tmp)"
    flutter build "$@" --build-dir "$BUILD_ROOT"
    ;;
  run)
    shift
    echo "==> flutter run --build-dir $BUILD_ROOT (caches in /tmp) $*"
    flutter run --build-dir "$BUILD_ROOT" "$@"
    ;;
  analyze|test|pub)
    # These don't produce heavy build artifacts
    flutter "$@"
    ;;
  *)
    echo "Usage: $0 {clean|build <target>|run [args]|analyze|test|pub get}"
    echo ""
    echo "All heavy caches (Gradle, Pub, build) are forced to /tmp by default."
    echo "Override with:"
    echo "  GATEPASSX_FLUTTER_BUILD_DIR=... GRADLE_USER_HOME=... ./scripts/build-flutter.sh ..."
    exit 1
    ;;
esac
