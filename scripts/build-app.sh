#!/bin/bash
# Build script for SunnyZ macOS app
# Creates a distributable .app bundle from Swift package
#
# Usage:
#   ./build-app.sh           — uses VERSION file as the version
#   ./build-app.sh 1.2.0     — overrides version for this build

set -e  # Exit on error

# ---------------------------------------------------------------------------
# Version resolution — single source of truth is the VERSION file.
# A CLI argument overrides it (useful for CI / hotfix builds).
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$REPO_ROOT/VERSION"

if [ -n "$1" ]; then
    VERSION="$1"
elif [ -f "$VERSION_FILE" ]; then
    VERSION="$(tr -d '[:space:]' < "$VERSION_FILE")"
else
    echo "❌ No version supplied and $VERSION_FILE not found."
    echo "   Create a VERSION file or pass the version as the first argument."
    exit 1
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
APP_NAME="SunnyZ"
BUNDLE_ID="com.sangosho.SunnyZ"
BUILD_DIR="$REPO_ROOT/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
FRAMEWORKS="$CONTENTS/Frameworks"

echo "🔨 Building $APP_NAME v$VERSION..."

# Guard against accidental deletion if variable expansion fails
if [ -z "$APP_BUNDLE" ]; then
    echo "❌ APP_BUNDLE is empty — aborting to prevent accidental deletion"
    exit 1
fi

# Clean previous build
echo "🧹 Cleaning previous build..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"
mkdir -p "$FRAMEWORKS"

# Build the Swift package
echo "📦 Building Swift package..."
(cd "$REPO_ROOT" && swift build -c release 2>&1 | grep -E "(error|warning|Building|Linking)" || true)

# Copy executable
echo "📋 Copying executable..."
cp "$REPO_ROOT/.build/release/$APP_NAME" "$MACOS/"

# Add rpath for Frameworks folder so the app can find Sparkle
echo "🔗 Setting library search path..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/$APP_NAME" 2>/dev/null || echo "   (rpath may already exist)"

# Copy resources (bundle, etc.)
echo "📚 Copying resources..."
if [ -d "$REPO_ROOT/.build/release/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "$REPO_ROOT/.build/release/${APP_NAME}_${APP_NAME}.bundle" "$RESOURCES/"
fi

# Copy Assets.xcassets if it exists
if [ -d "$REPO_ROOT/$APP_NAME/Assets.xcassets" ]; then
    echo "🎨 Copying assets..."
    mkdir -p "$RESOURCES/Assets.xcassets"
    cp -R "$REPO_ROOT/$APP_NAME/Assets.xcassets/." "$RESOURCES/Assets.xcassets/"
fi

# Copy Sparkle framework — check arch-specific path first, then generic
echo "📚 Copying Sparkle framework..."
SPARKLE_SOURCE="$REPO_ROOT/.build/arm64-apple-macosx/release/Sparkle.framework"
if [ ! -d "$SPARKLE_SOURCE" ]; then
    SPARKLE_SOURCE="$REPO_ROOT/.build/release/Sparkle.framework"
fi
if [ -d "$SPARKLE_SOURCE" ]; then
    cp -R "$SPARKLE_SOURCE" "$FRAMEWORKS/"
    echo "✅ Sparkle framework copied"
else
    echo "⚠️  Warning: Sparkle framework not found at $SPARKLE_SOURCE"
    echo "   App may not launch correctly."
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
    <key>SUPublicEDKey</key>
    <string>MCowBQYDK2VwAyEARqWxzksTGpaFI+X9OINC+IGsmISGOSJnf6/Q8xaKnIw=</string>
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/sangosho/sunnyz/main/appcast.xml</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
</dict>
</plist>
EOF

# Set executable permissions
chmod +x "$MACOS/$APP_NAME"

# Code sign frameworks and app
echo "✍️  Applying code signatures..."

ENTITLEMENTS="$REPO_ROOT/SunnyZ.entitlements"

if [ -d "$FRAMEWORKS/Sparkle.framework" ]; then
    SPARKLE_VERSION="$FRAMEWORKS/Sparkle.framework/Versions/Current"

    # Sign XPC services first (innermost, with sandbox entitlements)
    if [ -d "$SPARKLE_VERSION/XPCServices" ]; then
        echo "   Signing Sparkle XPC services..."
        for xpc in "$SPARKLE_VERSION/XPCServices"/*.xpc; do
            [ -d "$xpc" ] && codesign --force --deep --sign - "$xpc" 2>/dev/null || true
        done
    fi

    # Sign Updater.app (with entitlements so it can talk to the main process)
    if [ -d "$SPARKLE_VERSION/Updater.app" ]; then
        echo "   Signing Sparkle Updater.app..."
        codesign --force --deep --sign - "$SPARKLE_VERSION/Updater.app" 2>/dev/null || true
    fi

    # Sign Autoupdate tool
    if [ -f "$SPARKLE_VERSION/Autoupdate" ]; then
        echo "   Signing Sparkle Autoupdate tool..."
        codesign --force --sign - "$SPARKLE_VERSION/Autoupdate" 2>/dev/null || true
    fi

    # Sign the framework itself (after all nested binaries are signed)
    echo "   Signing Sparkle framework..."
    codesign --force --sign - "$FRAMEWORKS/Sparkle.framework" 2>/dev/null || true
fi

# Sign the main app bundle with entitlements
echo "   Signing main app bundle..."
if [ -f "$ENTITLEMENTS" ]; then
    codesign --force --sign - --entitlements "$ENTITLEMENTS" "$APP_BUNDLE" 2>/dev/null || true
else
    codesign --force --sign - "$APP_BUNDLE" 2>/dev/null || true
fi

# Verify the bundle
echo "✅ Verifying bundle structure..."
if [ -f "$MACOS/$APP_NAME" ] && [ -f "$CONTENTS/Info.plist" ]; then
    echo "✅ Bundle structure valid!"
    if [ -d "$FRAMEWORKS/Sparkle.framework" ]; then
        echo "✅ Sparkle framework included"
    else
        echo "⚠️  Warning: Sparkle framework missing"
    fi
else
    echo "❌ Bundle structure invalid!"
    exit 1
fi

# Show app size
APP_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)
echo ""
echo "✨ Build complete! v$VERSION"
echo "📦 App bundle: $APP_BUNDLE"
echo "📏 Size: $APP_SIZE"
echo ""
echo "To test: open '$APP_BUNDLE'"
echo "To create release: ./scripts/create-release.sh $VERSION"
