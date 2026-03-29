# SunnyZ ☀️

> Late-stage capitalism meets "touch grass."

A macOS **menu bar app** that taxes you for staying indoors too long.

## The Pitch

After 4 hours in darkness, your display brightness gets clamped to 50%. Pay $0.99 to unlock it, or subscribe for $4.99/month to become a Premium Cave Dweller™.

**The outdoors is now a premium subscription tier.**

## Features

- ☀️ **Menu bar icon** - Changes color based on your tax status
- 🌡️ **Live lux meter** - Reads your Mac's ambient light sensor
- 🦇 **Cave Dweller Timer** - Tracks time since last sunlight
- 💸 **Sunlight Tax** - $0.99 microtransaction to restore brightness
- 👑 **Premium** - $4.99/month for unlimited cave privileges
- 📊 **Quick stats** - Click the menu bar icon for instant status

## How It Works

1. App lives in your menu bar (no dock icon)
2. Monitors ambient light via IOKit
3. After 4h in darkness: brightness limited to 50%
4. Click menu bar icon → pay tax or go outside
5. Premium subscribers never pay tax

## Installation

```bash
git clone https://github.com/sangosho/sunnyz.git
cd sunnyz
swift build
# Run:
swift run
# Or build release:
swift build -c release
```

## Permissions

The app needs **Accessibility** permissions to control display brightness.

## Architecture

```
SunnyZ/
├── SunnyZApp.swift           # App delegate, menu bar setup
├── MenuBarController.swift   # Status item + popover management
├── Managers/
│   └── SunlightTaxManager.swift  # Tax logic + IOKit sensor reading
└── Views/
    ├── MenuPopoverView.swift       # Main menu popover UI
    ├── TaxPaywallView.swift        # Tax payment window
    └── PremiumSubscriptionView.swift  # Premium upsell
```

## The Joke

- Subscription fatigue → Everything's a subscription now
- Late-stage capitalism → Monetizing sunlight
- "Touch grass" → The outdoors as premium DLC
- Microtransactions → Pay to unlock basic functionality

## License

MIT — Because even sunlight taxes should be open source.

---

*Remember: This is satire. Go outside. It's free.* ☀️
