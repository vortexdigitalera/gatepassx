#!/usr/bin/env bash
# setup-android-signing.sh
# Generate a DEVELOPMENT Android keystore + key.properties (for local testing).
# This produces a debug-like key. For real releases use a separate long-lived RELEASE keystore + CI secrets.
#
# For production RELEASE builds in CI, configure the ANDROID_RELEASE_* secrets instead (see README).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
KEYSTORE_DIR="$PROJECT_DIR/mobile/android"
KEYSTORE_FILE="$KEYSTORE_DIR/upload-keystore.jks"
PROPS_FILE="$KEYSTORE_DIR/key.properties"

if [ -f "$KEYSTORE_FILE" ]; then
    echo "Keystore already exists at $KEYSTORE_FILE"
    echo "To regenerate, delete it first: rm $KEYSTORE_FILE"
else
    echo "Generating DEVELOPMENT keystore at $KEYSTORE_FILE ..."
    keytool -genkey -v \
        -keystore "$KEYSTORE_FILE" \
        -alias upload \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass changeit \
        -keypass changeit \
        -dname "CN=GatePassX Dev, OU=Engineering, O=GatePassX, L=Lagos, C=NG"

    echo "Keystore generated."
fi

if [ -f "$PROPS_FILE" ]; then
    echo "key.properties already exists at $PROPS_FILE"
else
    cat > "$PROPS_FILE" << 'PROPS'
storePassword=changeit
keyPassword=changeit
keyAlias=upload
storeFile=upload-keystore.jks
PROPS
    echo "key.properties created at $PROPS_FILE"
fi

echo ""
echo "Done. Local: flutter build apk --release  (will use this dev key via key.properties)"
echo "For real RELEASE key in CI: set ANDROID_RELEASE_KEYSTORE_BASE64 + password secrets (see README.md)"
