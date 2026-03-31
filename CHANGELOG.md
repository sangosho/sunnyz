# Changelog

All notable changes to SunnyZ will be documented in this file.

## [1.1.0] - 2026-03-31

### Added
- **"Enable real payments" toggle** in Settings → Tax Settings
- Satirical feature that allows users to opt-in to actual Apple Pay transactions
- Red-themed "Dangerous Settings" section with appropriate warnings
- TaxPaywallView shows "💀 REAL PAYMENT DUE" when toggle is enabled
- Scary warnings: "We warned you in settings. Proceed at your own risk"
- Peak late-stage capitalism: Pay real money for a satirical app about paying money

### Changed
- `dangerouslySkipPermission` setting persists via UserDefaults
- `payTax()` function checks the flag (still simulates - StoreKit2 not implemented)
- Payment button changes to "PAY $0.99 FOR REAL" when enabled

### Technical
- Setting defaults to OFF for everyone's safety
- Real payments would require StoreKit2, App Store Connect setup, sandbox testing
- UI fully functional and terrifying even though payments are still simulated

## [1.0.0] - 2026-04-01

### Added
- **Environment Classifier** - Multi-signal indoor/outdoor detection replacing fake lux sensor
  - Wi-Fi density as primary signal (8+ networks = indoor, 1-2 = outdoor)
  - Screen brightness as secondary signal
  - Power/thermal as supporting signals
  - Self-calibrating baseline per user
  - Temporal smoothing with 5-sample window
- **BrightnessController** - DisplayServices.framework wrapper for Apple Silicon
  - Dynamic loading via dlopen/dlsym
  - Works on M1/M2/M3 where IODisplayConnect returns NULL
- **Live UI timer** - "in dark" counter updates every second
- **Tax relief countdown** - Shows "Tax relief: 52 min left" after payment

### Changed
- Lux sensor now uses IOHIDManager with AppleSPUHIDInterface (falls back to estimation without root)
- Menu bar status shows "Indoors"/"Outdoors" with context-aware subtitles
- Time format changed from H:MM to HH:MM:SS
- Achievements page scrolling fixed with proper LazyVGrid constraints
- Tax relief properly persists for 1 hour (previously reset by periodic timer)
- Wi-Fi scanning runs on background thread (no UI blocking)

### Fixed
- Sparkle updater EdDSA key format (raw 32-byte instead of DER)
- SunlightTaxManagerTests time formatting tests
- Hardware-dependent lux sensor test

### Technical
- Added CoreWLAN framework dependency
- EnvironmentClassifier uses @MainActor with nonisolated WiFi scan
- DisplayServices loaded dynamically for compatibility
- Uncertainty threshold reduced (Wi-Fi count as tiebreaker)
