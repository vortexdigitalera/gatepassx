#!/usr/bin/env bash
# setup-android-signing.sh
# Generate a development Android keystore and configure key.properties for GatePassX.
#
# For production, use a real keystore and set environment variables in CI instead.
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
    echo "Generating development keystore at $KEYSTORE_FILE ..."
    keytool -genkey -v \
        -keystore "$KEYSTORE_FILE" \
        -alias upload \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass changeit \
        -keypass changeit \
        -dname "CN=GatePassX Dev, OU=Engineering, O=AHUON, L=Lagos, C=NG"

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
echo "Done! You can now run: flutter build apk --release"
echo "For CI, set the following environment variables instead:"
echo "  ANDROID_KEYSTORE_PATH  ANDROID_KEYSTORE_PASSWORD  ANDROID_KEY_ALIAS  ANDROID_KEY_PASSWORD"
