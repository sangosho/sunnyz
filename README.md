# SunnyZ ☀️

> Late-stage capitalism meets "touch grass."

A macOS **menu bar app** that taxes you for staying indoors too long.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-macOS%2013+-lightgrey)
![Swift](https://img.shields.io/badge/swift-5.7-orange)

## The Pitch

After 4 hours in darkness, your display brightness gets clamped to 50%. Pay $0.99 to unlock it, or subscribe for $4.99/month to become a Premium Cave Dweller™.

**The outdoors is now a premium subscription tier.**

## Features

### Core Features
- ☀️ **Menu bar icon** - Changes color based on your tax status (yellow=exempt, orange=warning, red=taxed, purple=premium)
- 🌡️ **Live lux meter** - Reads your Mac's ambient light sensor or estimates based on time
- 🦇 **Cave Dweller Timer** - Tracks time since last sunlight exposure
- 💸 **Sunlight Tax** - $0.99 microtransaction to restore brightness
- 👑 **Premium** - $4.99/month for unlimited cave privileges
- 📊 **Quick stats** - Click the menu bar icon for instant status

### Notifications
- ⏰ **30-minute warning** - Get notified before tax kicks in
- 🚨 **5-minute final warning** - Last chance to go outside
- 💳 **Tax applied alert** - Notification with Pay/Dismiss actions
- 📈 **Daily summary** - Your cave stats delivered daily at your chosen time
- 🔔 **Snarky reminders** - Periodic "go outside" reminders (3 snark levels)

### Settings & Customization
- ⚙️ **Settings panel** - Full control over all features (⌘, to open)
- 🎚️ **Snark level** - Choose from Mild, Medium, or Savage reminders
- ⏱️ **Tax threshold** - Set to 2h, 4h, or 8h
- 🌙 **Dark mode** - Full support for system dark mode
- 🚀 **Launch at login** - Start automatically with your Mac

### Achievements
Unlock badges for your cave-dwelling behavior:
- 🦇 **Vampire** - 24+ hours in darkness
- 🧌 **Cave Troll** - 7 days of 12h+ darkness
- 🌙 **Night Owl** - Active only 10pm-6am for 3 days
- 🏠 **Hermit** - 30 days without going outside
- 💎 **Diamond Hands** - Pay tax 10+ times
- 💸 **Big Spender** - Spend $10+ on taxes
- ☀️ **Touch Grass** - Actually go outside after 4h+ darkness (rare!)

### Smart Features
- 😴 **Sleep-aware** - Doesn't count sleep time toward tax
- 🖥️ **Display handling** - Works with multiple displays, handles disconnect/reconnect
- 🔒 **Privacy-first** - No data collected, everything stored locally
- ♿ **Accessible** - Full VoiceOver and Dynamic Type support
- ✨ **Auto-updates** - Sparkle-powered automatic updates (one-click install)

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘,` | Open Settings |
| `⌘Q` | Quit SunnyZ |

## Installation

### Download Release (Recommended)

1. Download the latest `SunnyZ-X.Y.Z-macos-arm64.zip` from [Releases](https://github.com/sangosho/sunnyz/releases)
2. Extract the zip file
3. Move `SunnyZ.app` to your Applications folder
4. Launch the app

**Requires:** macOS 13.0+ and Apple Silicon (M1/M2/M3/M4)

### Build from Source

```bash
git clone https://github.com/sangosho/sunnyz.git
cd sunnyz

# Build distributable .app bundle:
./build-app.sh

# Run tests:
swift test

# Or run directly (limited features):
swift run
```

See [BUILD.md](BUILD.md) for detailed build instructions and distribution guide.

## Permissions

The app needs **Accessibility** permissions to control display brightness.

**Note:** No actual payments are processed - this is satire! The "tax" and "premium" are simulated.

## How It Works

1. App lives in your menu bar (no dock icon)
2. Monitors ambient light via IOKit ALS APIs
3. After 4h in darkness: brightness limited to 50%
4. Click menu bar icon → pay fake tax or go outside
5. Premium subscribers never pay tax
6. Sleep time is not counted toward darkness

## Architecture

```
SunnyZ/
├── SunnyZApp.swift              # App entry, lifecycle, keyboard shortcuts
├── MenuBarController.swift      # Status item + popover management
├── Managers/
│   ├── SunlightTaxManager.swift     # Core tax logic + brightness control
│   ├── NotificationManager.swift    # UserNotifications with deduplication
│   ├── SettingsManager.swift        # UserDefaults wrapper
│   ├── LuxSensorManager.swift       # IOKit ALS reading with fallback
│   ├── AchievementManager.swift     # Badge tracking + confetti
│   └── SnarkManager.swift           # Context-aware message generation
├── Views/
│   ├── MenuPopoverView.swift        # Main menu UI with confetti
│   ├── TaxPaywallView.swift         # Tax payment with loading state
│   ├── PremiumSubscriptionView.swift # Premium upsell
│   ├── SettingsView.swift           # Settings panel (4 tabs)
│   └── AchievementsView.swift       # Badge gallery with sharing
├── Models/
│   ├── Achievement.swift            # Badge data model
│   └── ...
└── SunnyZTests/                    # XCTest suite
    ├── AchievementTests.swift      # Achievement model tests
    ├── SettingsManagerTests.swift   # Settings persistence tests
    ├── SnarkManagerTests.swift      # Snarky message tests
    └── SunlightTaxManagerTests.swift # Tax logic tests
```

## Troubleshooting

### App doesn't control brightness
- Grant **Accessibility** permissions in System Settings → Privacy & Security → Accessibility
- Restart the app after granting permissions
- Some external displays may not support brightness control

### Notifications not appearing
- Enable notifications in System Settings → Notifications → SunnyZ
- Check that "Do Not Disturb" or Focus modes are off
- The app requests notification permission on first launch

### Lux sensor shows "Estimated"
- This is normal on Macs without ambient light sensors
- The app falls back to time-based estimation
- Lux readings are approximate and used for detecting relative light changes

### Time in darkness seems wrong
- Sleep time is subtracted from darkness calculation
- If you deny notifications, warnings won't appear
- Tax threshold can be changed in Settings → Tax Settings

### App crashes or freezes
- Check Console app for crash logs
- Try resetting all stats in Settings → About → Reset All Stats
- Reinstall the app if issues persist

### Multiple displays
- Brightness control applies to the primary display
- ALS sensor is read from the built-in display on MacBooks

### App crashes on `swift run`
- This is expected — `UNUserNotificationCenter` requires a .app bundle
- Notifications are automatically disabled when not running from Xcode
- Use Xcode for the full experience: `open Package.swift`

## App Store Information

- **Category:** Lifestyle / Utilities
- **Keywords:** sunlight, health, productivity, satire, wellness, screen time
- **Privacy:** No data collected. All information stored locally on your device.

## The Joke

- Subscription fatigue → Everything's a subscription now
- Late-stage capitalism → Monetizing sunlight
- "Touch grass" → The outdoors as premium DLC
- Microtransactions → Pay to unlock basic functionality

**Remember: This is satire. Go outside. It's free.** ☀️

## Version History

See [CHANGELOG.md](CHANGELOG.md) for full version history.

### 1.0.0 (Sprint 5)
- Final polish and integration
- Keyboard shortcuts (⌘, for settings)
- Sleep/wake handling
- Notification deduplication
- Display disconnect/reconnect support
- Dark mode support throughout
- Comprehensive documentation

## License

MIT — Because even sunlight taxes should be open source.

---

*Built with Swift, snark, and a desperate need to touch grass.* 🌱
