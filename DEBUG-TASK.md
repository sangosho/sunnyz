# Debug Panel Implementation

## Overview
Add a developer debug panel to SunnyZ that lets the user manually trigger states, override sensor readings, and test features without waiting for real conditions.

## Requirements

### Debug Mode Toggle
- Add `debugModeEnabled` to SettingsManager (persisted, defaults to `false`)
- Only show debug panel when debug mode is on
- Easy toggle: click the app version in settings 5 times (Easter egg style), or add a command-line flag

### Debug Panel (new file: `SunnyZ/Views/DebugPanelView.swift`)

A SwiftUI view accessible from Settings when debug mode is enabled, with these sections:

#### 1. Lux Simulator
- Slider to manually set lux value (0-1000)
- Toggle: "Override real sensor" — when on, `LuxSensorManager.readLux()` returns the slider value
- Current lux display + accuracy label
- Quick presets: "Pitch Black" (0), "Dim Room" (30), "Office" (200), "Window Light" (500), "Direct Sun" (1000)

#### 2. Tax State Override
- Buttons to force tax status: Exempt / Warning / Taxed / Premium
- "Skip to taxed" button — sets `timeInDarkness` to just past the threshold
- "Reset timer" button — clears darkness tracking
- Display current time in darkness (editable)

#### 3. Achievement Trigger
- List of all 7 achievements with individual "Unlock" buttons
- "Reset all achievements" button
- Shows current unlock state next to each

#### 4. Notification Testing
- "Send warning notification" button
- "Send tax applied notification" button
- "Send daily summary" button
- "Send snarky reminder" button

#### 5. Time Acceleration
- Multiplier slider: 1x, 5x, 10x, 60x
- When active, the monitoring timer runs faster so tax kicks in quicker
- "Reset to 1x" button

### Integration

#### LuxSensorManager changes:
- Add `@Published var debugOverrideLux: Double?` property
- In `readLux()`, if `debugOverrideLux != nil` and override is enabled, return that value with `.accurate` accuracy
- Add `setDebugOverride(_ lux: Double?)` and `clearDebugOverride()` methods

#### SunlightTaxManager changes:
- Add `@Published var debugModeEnabled: Bool` (bound to settings)
- Add `@Published var timeAcceleration: Double = 1.0`
- Modify the monitoring timer to use `5.0 / timeAcceleration` interval when debug mode is on
- Add methods: `forceTaxStatus(_ status: TaxStatus)`, `forceTimeInDarkness(_ duration: TimeInterval)`, `resetDarknessTimer()`

#### SettingsView changes:
- Add a "Developer" section at the bottom (only visible in debug mode)
- Include toggle for debug mode
- Button to open DebugPanelView as a sheet
- Show build number and version

#### MenuBarController changes:
- When debug mode is on, show a small "🔧" badge or "(DEBUG)" next to the menu bar title

### Code Style
- Match existing code conventions (one type per file, Combine publishers, @MainActor)
- Add `// MARK: - Debug` sections to modified managers
- All debug UI should have a distinct visual style (e.g., orange/red accent, subtle background)
- Wrap all debug code in `#if DEBUG` where it makes sense, but keep the override mechanisms available in release builds (toggled off by default)

### Files to create:
- `SunnyZ/Views/DebugPanelView.swift`

### Files to modify:
- `SunnyZ/Managers/LuxSensorManager.swift`
- `SunnyZ/Managers/SunlightTaxManager.swift`
- `SunnyZ/Managers/SettingsManager.swift`
- `SunnyZ/Managers/NotificationManager.swift` (add test notification methods)
- `SunnyZ/Views/SettingsView.swift`
- `SunnyZ/MenuBarController.swift`

### Git
- Commit with message: "Add developer debug panel for testing"
- Push to origin HEAD:main
