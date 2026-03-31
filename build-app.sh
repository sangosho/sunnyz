#!/bin/bash
# Build script for SunnyZ macOS app
# Creates a distributable .app bundle from Swift package

set -e  # Exit on error

# Configuration
APP_NAME="SunnyZ"
BUNDLE_ID="com.sangosho.SunnyZ"
VERSION="1.0.0"
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "🔨 Building $APP_NAME..."

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Build the Swift package
echo "📦 Building Swift package..."
swift build -c release 2>&1 | grep -E "(error|warning|Building|Linking)" || true

# Copy executable
echo "📋 Copying executable..."
cp .build/release/$APP_NAME "$MACOS/"

# Copy resources (bundle, etc.)
echo "📚 Copying resources..."
if [ -d ".build/release/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R .build/release/${APP_NAME}_${APP_NAME}.bundle "$RESOURCES/"
fi

# Copy Assets.xcassets if it exists
if [ -d "$APP_NAME/Assets.xcassets" ]; then
    echo "🎨 Copying assets..."
    mkdir -p "$RESOURCES/Assets.xcassets"
    cp -R $APP_NAME/Assets.xcassets/* "$RESOURCES/Assets.xcassets/"
fi

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>SunnyZ</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
EOF

# Set executable permissions
chmod +x "$MACOS/$APP_NAME"

# Optional: Code sign with ad-hoc signature (prevents some macOS warnings)
echo "✍️  Applying ad-hoc code signature..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>&1 | grep -v "replacing existing" || true

# Verify the bundle
echo "✅ Verifying bundle structure..."
if [ -f "$MACOS/$APP_NAME" ] && [ -f "$CONTENTS/Info.plist" ]; then
    echo "✅ Bundle structure valid!"
else
    echo "❌ Bundle structure invalid!"
    exit 1
fi

# Show app size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "✨ Build complete!"
echo "📦 App bundle: $APP_BUNDLE"
echo "📏 Size: $APP_SIZE"
echo ""
echo "To test: open '$APP_BUNDLE'"
echo "To create release: See create-release.sh"
