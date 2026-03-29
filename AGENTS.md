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
# SPM
swift build
swift run

# Xcode
open SunnyZ.xcodeproj  # or generate with `swift package generate-xcodeproj`
```

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

- No formal test suite yet (v1.0)
- Manual testing: run the app, trigger tax conditions by setting system clock or covering sensor
- Key scenarios to verify: tax triggers, brightness clamping, payment flow, achievements, notifications

## Common Tasks

| Task | How |
|------|-----|
| Add a new achievement | Add case to `Achievement.Category`, add model in `AchievementManager.checkAchievements()` |
| Add a new setting | Add key to `SettingsManager`, add control to `SettingsView.swift` |
| Change snark level | Add strings to `SnarkManager` for the appropriate level |
| Add notification | Use `NotificationManager.scheduleNotification()` |
