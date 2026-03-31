#!/bin/bash
# Generate EdDSA keys for Sparkle update signing

set -e

PRIVATE_KEY_FILE="./sparkle_private_key.pem"
PUBLIC_KEY_FILE="./sparkle_public_key.pem"

echo "🔐 Generating Sparkle EdDSA keys..."

# Generate private key
if [ -f "$PRIVATE_KEY_FILE" ]; then
    echo "⚠️  Private key already exists: $PRIVATE_KEY_FILE"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Keeping existing keys"
        exit 0
    fi
fi

openssl genpkey -algorithm Ed25519 -out "$PRIVATE_KEY_FILE"

# Export public key
openssl pkey -pubout -in "$PRIVATE_KEY_FILE" -out "$PUBLIC_KEY_FILE"

# Set permissions
chmod 600 "$PRIVATE_KEY_FILE"
chmod 644 "$PUBLIC_KEY_FILE"

echo ""
echo "✅ Keys generated successfully!"
echo ""
echo "📋 Public key (add to UpdateManager.swift):"
echo "---------------------------------------------"
cat "$PUBLIC_KEY_FILE"
echo "---------------------------------------------"
echo ""
echo "🔐 Store these keys securely:"
echo "   Private: $PRIVATE_KEY_FILE (keep secret!)"
echo "   Public:  $PUBLIC_KEY_FILE"
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Add $PRIVATE_KEY_FILE to .gitignore"
echo "   - Never commit the private key"
echo "   - Add the public key to your Info.plist or UpdateManager"
