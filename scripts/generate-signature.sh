#!/bin/bash
# Generate EdDSA signature for Sparkle

set -e

ARCHIVE_PATH="$1"

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "❌ Archive not found: $ARCHIVE_PATH"
    exit 1
fi

# Check if we have the private key
PRIVATE_KEY_FILE="./sparkle_private_key.pem"

if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    echo "⚠️  Sparkle private key not found"
    echo ""
    echo "Generate one with:"
    echo "  openssl genpkey -algorithm Ed25519 -out $PRIVATE_KEY_FILE"
    echo ""
    echo "Then add the public key to your UpdateManager:"
    echo "  openssl pkey -pubout -in $PRIVATE_KEY_FILE -out sparkle_public_key.pem"
    echo ""
    exit 1
fi

# Generate signature using openssl (Ed25519) - no explicit digest for EdDSA
TEMP_SIG=$(mktemp)
openssl pkeyutl -sign -inkey "$PRIVATE_KEY_FILE" -in "$ARCHIVE_PATH" -out "$TEMP_SIG"
SIGNATURE=$(base64 -i "$TEMP_SIG" 2>/dev/null || base64 "$TEMP_SIG")
rm -f "$TEMP_SIG"

echo "$SIGNATURE"
