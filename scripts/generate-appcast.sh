#!/bin/bash
# Generate appcast.xml for Sparkle updates

set -e

# Configuration
VERSION=${1:-"1.0.0"}
BUILD_DIR="./build"
APP_NAME="SunnyZ"
ARCHIVE_NAME="$APP_NAME-$VERSION-macos-arm64.zip"
ARCHIVE_PATH="$BUILD_DIR/$ARCHIVE_NAME"
APPCAST_FILE="./appcast.xml"
DOWNLOAD_BASE_URL="https://github.com/sangosho/sunnyz/releases/download/v${VERSION}"
GITHUB_REPO="sangosho/sunnyz"

# Check if archive exists
if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "❌ Archive not found: $ARCHIVE_PATH"
    echo "Run ./create-release.sh $VERSION first"
    exit 1
fi

# Get file info
FILE_SIZE=$(stat -f%z "$ARCHIVE_PATH" 2>/dev/null || stat -c%s "$ARCHIVE_PATH")
FILE_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S GMT")
SHA256=$(shasum -a 256 "$ARCHIVE_PATH" | awk '{print $1}')

# Create appcast.xml
cat > "$APPCAST_FILE" << EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>SunnyZ Appcast</title>
    <link>https://github.com/${GITHUB_REPO}/releases/latest</link>
    <description>Most recent SunnyZ releases</description>
    <language>en</language>

    <item>
      <title>Version ${VERSION}</title>
      <link>${DOWNLOAD_BASE_URL}/${ARCHIVE_NAME}</link>
      <sparkle:version>${VERSION}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description>
        <![CDATA[
          <h2>SunnyZ ${VERSION}</h2>
          <ul>
            <li>Production-ready macOS app bundle</li>
            <li>Automatic updates via Sparkle</li>
            <li>Full notification support</li>
            <li>Complete build and release pipeline</li>
          </ul>
        ]]>
      </description>
      <pubDate>${FILE_DATE}</pubDate>
      <enclosure
        url="${DOWNLOAD_BASE_URL}/${ARCHIVE_NAME}"
        sparkle:version="${VERSION}"
        sparkle:shortVersionString="${VERSION}"
        sparkle:edSignature="$(./scripts/generate-signature.sh "$ARCHIVE_PATH")"
        length="${FILE_SIZE}"
        type="application/octet-stream"
      />
    </item>

  </channel>
</rss>
EOF

echo "✅ Generated appcast.xml"
echo ""
echo "📋 Appcast details:"
echo "   Version: $VERSION"
echo "   File: $ARCHIVE_NAME"
echo "   Size: $FILE_SIZE bytes"
echo "   SHA-256: $SHA256"
echo ""
echo "📝 Next steps:"
echo "1. Commit and push appcast.xml to GitHub"
echo "2. Tag and push release: git tag v$VERSION && git push --tags"
echo "3. Create GitHub release with the ZIP archive"
