# Changelog

All notable changes to SunnyZ will be documented in this file.

## [1.0.0] - 2026-04-01

### Added
- **Environment Classifier** - Multi-signal indoor/outdoor detection
  - Wi-Fi density as primary signal (8+ networks = indoor, 1-2 = outdoor)
  - Screen brightness and thermal as supporting signals
  - Self-calibrating baseline per user
  - Temporal smoothing with 5-sample window
- **BrightnessController** - DisplayServices.framework wrapper for Apple Silicon
- **Live UI timer** - "in dark" counter updates every second (HH:MM:SS)
- **Tax relief countdown** - Shows remaining unlock time after payment
- **"Enable real payments" toggle** - Satirical opt-in to real Apple Pay (defaults OFF)

### Changed
- Menu bar shows "Indoors"/"Outdoors"/"Uncertain" with context-aware subtitles
- Wi-Fi scanning runs on background thread (no UI blocking)
- Time format changed from H:MM to HH:MM:SS

### Fixed
- Sparkle updater EdDSA key format
- Tax relief properly persists for 1 hour
- Achievements page scrolling
- Apple Silicon brightness control (IODisplayConnect returns NULL on M1+)

### Technical
- Added CoreWLAN framework dependency
- EnvironmentClassifier uses @MainActor with nonisolated WiFi scan
- DisplayServices loaded dynamically
