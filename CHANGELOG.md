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
- Initial release for April Fools hackathon
- Sunlight Tax feature - charges $0.99 after 4 hours in darkness
- Premium subscription tier - $4.99/month for unlimited cave dwelling
- Real-time lux monitoring with visual meter
- Cave Dweller Timer tracking time in darkness
- Tax paywall with unlock functionality
- Premium subscription upsell flow
- Statistics tracking (total tax paid, last sunlight)
- Dynamic UI themes based on tax status
