# SunnyZ ☀️

> Late-stage capitalism meets "touch grass."

SunnyZ is an iOS app for the April Fools hackathon that implements the **Sunlight Tax** — a satirical take on subscription culture and our relationship with the outdoors.

## The Pitch

Ambient light sensor detects if you've been in darkness (indoors) for 4+ hours; starts charging you $0.99 microtransactions to unlock brightness above 50%.

**The outdoors becomes a premium subscription tier.** Your cave-dwelling behavior is literally taxed.

## Features

- ☀️ **Real-time lux monitoring** - Track ambient light levels
- 🦇 **Cave Dweller Timer** - See how long you've been in darkness
- 💸 **Sunlight Tax** - Pay $0.99 to unlock brightness after 4 hours indoors
- 👑 **Premium Subscription** - $4.99/month for unlimited cave dwelling
- 📊 **Cave Stats** - Track your total tax paid and sunlight exposure
- 🎮 **Gamer Mode** - Optimized for marathon indoor sessions

## How It Works

1. The app monitors your ambient light levels
2. After 4 hours in darkness, the Sunlight Tax kicks in
3. Your screen brightness is limited to 50%
4. Pay $0.99 to unlock full brightness for 1 hour
5. Or subscribe to Premium for unlimited cave dwelling privileges

## Technical Stack

- **SwiftUI** for the UI
- **CoreMotion** for ambient light estimation
- **StoreKit** (simulated for hackathon) for in-app purchases
- **UIScreen** API for brightness control

## Installation

```bash
git clone https://github.com/sangosho/sunnyz.git
cd sunnyz
open SunnyZ.xcodeproj
```

## Architecture

```
SunnyZ/
├── SunnyZ/
│   ├── SunnyZApp.swift           # App entry point
│   ├── Managers/
│   │   └── SunlightTaxManager.swift  # Core tax logic
│   └── Views/
│       ├── ContentView.swift     # Main dashboard
│       ├── TaxPaywallView.swift  # Tax payment UI
│       └── PremiumSubscriptionView.swift  # Premium upsell
├── SunnyZTests/
└── Package.swift
```

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
