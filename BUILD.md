# Building SunnyZ for Distribution

Quick guide to building and distributing SunnyZ as a macOS app bundle.

## Prerequisites

- macOS 13.0+
- Xcode Command Line Tools: `xcode-select --install`
- Swift 5.9+

## Quick Start

### 1. Build the App

```bash
./build-app.sh
```

This creates `./build/SunnyZ.app` - a complete macOS app bundle ready to run.

### 2. Test the App

```bash
open ./build/SunnyZ.app
```

- Click the ☀️ icon in your menu bar
- Grant permissions when prompted (Notifications, Accessibility)
- Try the Debug panel to test notifications

### 3. Create a Release

```bash
./create-release.sh 1.0.0
```

This creates:
- `SunnyZ-1.0.0-macos-arm64.zip` - Ready for GitHub upload
- Checksums (SHA-256, MD5)
- Release notes template

## Project Structure

```
SunnyZ/
├── SunnyZ/              # Source code
├── build-app.sh         # Build script
├── create-release.sh    # Release prep script
└── build/
    └── SunnyZ.app       # Built app bundle
```

## Distribution

### GitHub Release

1. Run: `./create-release.sh 1.0.0`
2. Go to: https://github.com/sangosho/sunnyz/releases/new
3. Create tag: `v1.0.0`
4. Upload: `./build/SunnyZ-1.0.0-macos-arm64.zip`
5. Paste the generated release notes

### Code Signing (Optional)

To avoid "unidentified developer" warnings for users:

```bash
# Get your Apple Developer certificate
codesign --force --deep --sign "Developer ID Application: Your Name" ./build/SunnyZ.app
```

## Troubleshooting

**App won't open:**
- Make sure `LSUIElement` is `true` in Info.plist (menu bar only)
- Check Console.app for crash logs

**Notifications not working:**
- Verify bundle identifier matches: `com.sangosho.SunnyZ`
- Check System Settings → Notifications → SunnyZ

**Code signature issues:**
- Run: `codesign --remove-signature ./build/SunnyZ.app`
- Re-sign with your certificate

## Development vs Production

**Development (swift run):**
- Quick testing
- No app bundle
- Limited macOS integration

**Production (./build-app.sh):**
- Full macOS app bundle
- Proper notifications
- Distributable
- Code signature ready

## Version Bump

Update version in:
1. `build-app.sh` - VERSION variable
2. `create-release.sh` - Default version
3. Run: `./create-release.sh X.Y.Z`
