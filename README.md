# SunnyZ ☀️

> Late-stage capitalism meets "touch grass."

SunnyZ is a macOS app for the April Fools hackathon that implements the **Sunlight Tax** — a satirical take on subscription culture and our relationship with the outdoors.

## The Pitch

Ambient light sensor detects if you've been in darkness (indoors) for 4+ hours; starts charging you $0.99 microtransactions to unlock display brightness above 50%.

**The outdoors becomes a premium subscription tier.** Your cave-dwelling behavior is literally taxed.

## Features

- ☀️ **Real-time lux monitoring** - Read from Mac's ambient light sensor via IOKit
- 🦇 **Cave Dweller Timer** - See how long you've been in darkness
- 💸 **Sunlight Tax** - Pay $0.99 to unlock brightness after 4 hours indoors
- 👑 **Premium Subscription** - $4.99/month for unlimited cave dwelling
- 📊 **Cave Stats** - Track your total tax paid and sunlight exposure
- 💻 **Developer Mode** - Optimized for marathon coding sessions

## How It Works

1. The app reads your Mac's ambient light sensor via IOKit
2. After 4 hours in darkness, the Sunlight Tax kicks in
3. Your display brightness is limited to 50%
4. Pay $0.99 to unlock full brightness for 1 hour
5. Or subscribe to Premium for unlimited cave dwelling privileges

## Technical Stack

- **SwiftUI** for the native macOS UI
- **IOKit** for ambient light sensor access and display brightness control
- **StoreKit** (simulated for hackathon) for in-app purchases
- **Combine** for reactive state management

## Installation

### Build from source:

```bash
git clone https://github.com/sangosho/sunnyz.git
cd sunnyz
swift build
swift run
```

### Or open in Xcode:

```bash
open Package.swift
```

## Architecture

```
SunnyZ/
├── SunnyZ/
│   ├── SunnyZApp.swift           # App entry point
│   ├── Managers/
│   │   └── SunlightTaxManager.swift  # Core tax logic + IOKit integration
│   └── Views/
│       ├── ContentView.swift     # Main dashboard
│       ├── TaxPaywallView.swift  # Tax payment UI
│       └── PremiumSubscriptionView.swift  # Premium upsell
├── SunnyZTests/
└── Package.swift
```

## Permissions

The app requires:
- **Accessibility permissions** (for brightness control)
- **Sensor access** (for ambient light reading)

## The Joke

This app satirizes:
- Subscription fatigue (everything is a subscription now)
- Late-stage capitalism (monetizing basic human needs)
- "Touch grass" culture (the outdoors as a premium experience)
- Microtransactions (pay to unlock basic functionality)

## License

MIT — Because even sunlight taxes should be open source.

---

*Remember: This is a joke. Go outside. It's free.* ☀️
