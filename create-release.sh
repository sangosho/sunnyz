#!/bin/bash
# Prepare GitHub release for SunnyZ

set -e

# Configuration
APP_NAME="SunnyZ"
VERSION=${1:-"1.0.0"}
BUILD_DIR="./build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ARCHIVE_NAME="$APP_NAME-$VERSION-macos-arm64.zip"
ARCHIVE_PATH="$BUILD_DIR/$ARCHIVE_NAME"

echo "📦 Creating GitHub Release for $APP_NAME v$VERSION"
echo ""

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ App bundle not found at $APP_BUNDLE"
    echo "Run ./build-app.sh first"
    exit 1
fi

# Create ZIP archive
echo "🗜️  Creating ZIP archive..."
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME.app" "$ARCHIVE_NAME"
cd - > /dev/null

# Calculate checksums
echo "🔐 Calculating checksums..."
SHA256=$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')
MD5=$(md5 -q "$ARCHIVE_PATH")

# Get file size
FILE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)

echo ""
echo "✅ Release ready!"
echo ""
echo "📦 Archive: $ARCHIVE_PATH"
echo "📏 Size: $FILE_SIZE"
echo ""
echo "📋 Checksums:"
echo "   SHA-256: $SHA256"
echo "   MD5:     $MD5"
echo ""
echo "📝 Release Notes Template:"
echo "---"
cat << RELEASE_NOTES
## SunnyZ v$VERSION

### Installation
1. Download \`$ARCHIVE_NAME\`
2. Extract the zip file
3. Move \`SunnyZ.app\` to your Applications folder
4. Launch the app

### Verification
**SHA-256:** \`$SHA256\`

### What's New
- Your changes here

### Requirements
- macOS 13.0 or later
- Apple Silicon (M1/M2/M3/M4)

### Permissions
On first launch, grant:
- **Notifications** - For sunlight tax warnings
- **Accessibility** - To monitor screen brightness
- **Login Items** - Optional: Auto-launch at login
RELEASE_NOTES

echo "---"
echo ""
echo "🚀 To publish:"
echo "1. Create a new release on GitHub: https://github.com/sangosho/sunnyz/releases/new"
echo "2. Tag: v$VERSION"
echo "3. Upload: $ARCHIVE_PATH"
echo "4. Paste the release notes above"
