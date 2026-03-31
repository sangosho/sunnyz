# AGENTS.md — SunnyZ

> Guidelines for AI coding agents working on this repository.

## Project Overview

SunnyZ is a macOS menu bar app that implements the "Sunlight Tax" — after 4 hours in darkness, it clamps display brightness to 50% and charges $0.99 to unlock. Built with Swift and SwiftUI.

## Architecture

```
SunnyZ/
├── App
│   ├── SunnyZApp.swift          # App entry point, menu bar setup
│   └── MenuBarController.swift  # NSMenu bar icon & popover
├── Models/
│   └── Achievement.swift        # Achievement data model (Codable)
├── Managers/
│   ├── LuxSensorManager.swift   # IOKit ambient light sensor
│   ├── SunlightTaxManager.swift # Core tax logic & brightness control
│   ├── SettingsManager.swift    # UserDefaults persistence
│   ├── NotificationManager.swift# UserNotifications scheduling
│   ├── AchievementManager.swift # Achievement tracking & unlocking
│   └── SnarkManager.swift       # Snarky reminder text generation
├── Views/
│   ├── ContentView.swift        # Main content wrapper
│   ├── MenuPopoverView.swift    # Menu bar dropdown UI
│   ├── SettingsView.swift       # Preferences panel (⌘,)
│   ├── TaxPaywallView.swift     # Payment UI for tax unlock
│   ├── PremiumSubscriptionView.swift # Subscription upsell
│   ├── AchievementsView.swift   # Achievement gallery
│   └── ConfettiView.swift       # Particle celebration overlay
└── Assets.xcassets/             # App icons, colors, assets
```

## Tech Stack

- **Language:** Swift 5.7+
- **UI:** SwiftUI
- **Platform:** macOS 13+ (Ventura)
- **Sensors:** IOKit (ambient light sensor)
- **Build:** Swift Package Manager / Xcode

## Build & Run

```bash
# Build distributable .app bundle (production)
./build-app.sh

# Run the built app
open ./build/SunnyZ.app

# Create GitHub release
./create-release.sh 1.0.0

# SPM (development)
swift build
swift run

# Xcode
open Package.swift
```

**Note:** Use `./build-app.sh` for production builds. The `swift run` command disables notifications (requires `.app` bundle).

## Code Conventions

- **Swift style:** Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- **File organization:** One type per file, grouped by domain (Models, Views, Managers)
- **State management:** SwiftUI `@StateObject` / `@ObservedObject` with Combine publishers
- **Persistence:** UserDefaults via `SettingsManager` — never access UserDefaults directly elsewhere
- **Notifications:** Always go through `NotificationManager`, respect user notification preferences
- **Accessibility:** All interactive views must have VoiceOver labels and support Dynamic Type

## What Not to Change

- The "Sunlight Tax" concept and snarky tone are core to the app's identity
- Don't remove or soften the humor — it's a feature, not a bug
- Achievement conditions are semi-realistic tracking (time in darkness, payments, etc.) — don't make them trivially easy to unlock
- Keep the privacy-first approach: no data leaves the device

## Testing

```bash
swift test
```

The test suite covers:
- **AchievementTests** — Model encoding/decoding, Equatable conformance, helper methods
- **SettingsManagerTests** — Default values, TaxThreshold enum, lux calibration, persistence
- **SnarkManagerTests** — Snark levels, reminder intervals, message generation
- **SunlightTaxManagerTests** — TaxStatus enum, initial state, time formatting, progress calculations

Tests run without hardware (no sensor/display required). Note: tests create `@MainActor` manager instances, so they use `async throws`.

### Known Limitation
- `swift run` disables notifications (requires `.app` bundle for `UNUserNotificationCenter`)
- Full testing requires running through Xcode: `open Package.swift`

## Common Tasks

| Task | How |
|------|-----|
| Build for distribution | Run `./build-app.sh` to create `./build/SunnyZ.app` |
| Create GitHub release | Run `./create-release.sh X.Y.Z` and upload the generated ZIP |
| Add a new achievement | Add case to `Achievement.Category`, add model in `AchievementManager.checkAchievements()` |
| Add a new setting | Add key to `SettingsManager`, add control to `SettingsView.swift` |
| Change snark level | Add strings to `SnarkManager` for the appropriate level |
| Add notification | Use `NotificationManager.scheduleNotification()` |
