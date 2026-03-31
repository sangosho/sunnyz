# SunnyZ ☀️

> Late-stage capitalism meets "touch grass."

A macOS menu bar app that taxes you for staying indoors too long.

## How It Works

1. App detects indoor/outdoor via Wi-Fi density, screen brightness, and thermal signals
2. After 4 hours indoors: screen brightness clamps to 50%
3. Pay $0.99 to unlock brightness for 1 hour
4. Or subscribe for $4.99/month to become a Premium Cave Dweller™

## Features

- **Environment detection** - Wi-Fi density as primary signal (no root required)
- **Live timer** - HH:MM:SS counter updates every second
- **Tax relief countdown** - See exactly how much unlock time remains
- **Menu bar UI** - Color-coded status (yellow=exempt, orange=warning, red=taxed, purple=premium)
- **Sleep-aware** - Sleep time doesn't count toward the tax

## Installation

1. Download the latest release from [github.com/sangosho/sunnyz/releases](https://github.com/sangosho/sunnyz/releases)
2. Extract the ZIP and move `SunnyZ.app` to Applications
3. **First launch:** Right-click the app → **Open** (required to bypass Gatekeeper)
   - If you see "SunnyZ cannot be opened," go to **System Settings → Privacy & Security** and click **Open Anyway**
4. Grant **Accessibility** permissions when prompted (required for brightness control)

**Requires:** macOS 13+ and Apple Silicon

## Build from Source

```bash
git clone https://github.com/sangosho/sunnyz.git
cd sunnyz
./scripts/build-app.sh
open ./build/SunnyZ.app
```

## Permissions

Grant **Accessibility** permissions for brightness control (System Settings → Privacy & Security → Accessibility).

## The Joke

Subscription fatigue + late-stage capitalism + "touch grass" = monetizing sunlight.

**Remember: This is satire. Go outside. It's free.** ☀️

## License

MIT
