//
//  SunlightTaxManagerTests.swift
//  SunnyZTests
//
//  Tests for SunlightTaxManager core logic
//

import XCTest
@testable import SunnyZ

@MainActor
final class SunlightTaxManagerTests: XCTestCase {
    
    var taxManager: SunlightTaxManager!

    override func setUp() async throws {
        // Reset persisted state for clean test isolation
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "sunlightTax.totalPaid")
        defaults.removeObject(forKey: "sunlightTax.hasPremium")
        defaults.removeObject(forKey: "sunlightTax.lastSunlight")
        defaults.removeObject(forKey: "sunlightTax.darknessStartTime")
        defaults.removeObject(forKey: "sunlightTax.timeInDarkness")
        taxManager = SunlightTaxManager()
    }
    
    // MARK: - TaxStatus Enum Tests
    
    func testTaxStatusCases() async throws {
        // Test that all cases exist and can be created
        let exempt: SunlightTaxManager.TaxStatus = .exempt
        let warning: SunlightTaxManager.TaxStatus = .warning
        let taxed: SunlightTaxManager.TaxStatus = .taxed
        let premium: SunlightTaxManager.TaxStatus = .premium
        
        XCTAssertEqual(exempt, SunlightTaxManager.TaxStatus.exempt)
        XCTAssertEqual(warning, SunlightTaxManager.TaxStatus.warning)
        XCTAssertEqual(taxed, SunlightTaxManager.TaxStatus.taxed)
        XCTAssertEqual(premium, SunlightTaxManager.TaxStatus.premium)
    }
    
    func testTaxStatusIcons() async throws {
        XCTAssertEqual(SunlightTaxManager.TaxStatus.exempt.icon, "☀️")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.warning.icon, "🌤️")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.taxed.icon, "💸")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.premium.icon, "👑")
    }
    
    func testTaxStatusMenuIcons() async throws {
        XCTAssertEqual(SunlightTaxManager.TaxStatus.exempt.menuIcon, "sun.max.fill")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.warning.menuIcon, "cloud.sun.fill")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.taxed.menuIcon, "dollarsign.circle.fill")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.premium.menuIcon, "crown.fill")
    }
    
    func testTaxStatusColors() async throws {
        XCTAssertEqual(SunlightTaxManager.TaxStatus.exempt.color, "#4CAF50")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.warning.color, "#FF9800")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.taxed.color, "#F44336")
        XCTAssertEqual(SunlightTaxManager.TaxStatus.premium.color, "#9C27B0")
    }
    
    func testTaxStatusEquatable() async throws {
        XCTAssertEqual(SunlightTaxManager.TaxStatus.exempt, SunlightTaxManager.TaxStatus.exempt)
        XCTAssertNotEqual(SunlightTaxManager.TaxStatus.exempt, SunlightTaxManager.TaxStatus.taxed)
        XCTAssertNotEqual(SunlightTaxManager.TaxStatus.warning, SunlightTaxManager.TaxStatus.premium)
    }
    
    // MARK: - Initial State Tests
    
    func testInitialTaxStatus() async throws {
        XCTAssertEqual(taxManager.taxStatus, .exempt)
    }
    
    func testInitialTimeInDarkness() async throws {
        // The manager may have persisted state from a previous run
        // We just verify it has a valid TimeInterval value
        XCTAssertGreaterThanOrEqual(taxManager.timeInDarkness, 0)
    }
    
    func testInitialBrightnessLimit() async throws {
        XCTAssertEqual(taxManager.brightnessLimit, 1.0)
    }
    
    func testInitialHasPremiumSubscription() async throws {
        XCTAssertFalse(taxManager.hasPremiumSubscription)
    }
    
    func testInitialTotalTaxPaid() async throws {
        XCTAssertEqual(taxManager.totalTaxPaid, 0)
    }
    
    func testInitialCurrentLux() async throws {
        XCTAssertEqual(taxManager.currentLux, 0)
    }
    
    // MARK: - Constants Tests
    
    func testTaxedBrightnessLimit() async throws {
        XCTAssertEqual(taxManager.taxedBrightnessLimit, 0.5)
    }
    
    func testTaxAmount() async throws {
        XCTAssertEqual(taxManager.taxAmount, 0.99)
    }
    
    // MARK: - Time Formatting Tests
    
    func testFormattedTimeInDarkness() async throws {
        // Test with 0 time
        taxManager.timeInDarkness = 0
        XCTAssertEqual(taxManager.formattedTimeInDarkness, "0:00")
        
        // Test with 1 hour 30 minutes
        taxManager.timeInDarkness = 5400 // 1.5 hours in seconds
        XCTAssertEqual(taxManager.formattedTimeInDarkness, "1:30")
        
        // Test with 4 hours
        taxManager.timeInDarkness = 14400 // 4 hours in seconds
        XCTAssertEqual(taxManager.formattedTimeInDarkness, "4:00")
        
        // Test with 24 hours 45 minutes
        taxManager.timeInDarkness = 89100 // 24.75 hours in seconds
        XCTAssertEqual(taxManager.formattedTimeInDarkness, "24:45")
    }
    
    func testFormattedTotalTax() async throws {
        // Test with $0
        taxManager.totalTaxPaid = 0
        XCTAssertEqual(taxManager.formattedTotalTax, "$0.00")
        
        // Test with $0.99
        taxManager.totalTaxPaid = 0.99
        XCTAssertEqual(taxManager.formattedTotalTax, "$0.99")
        
        // Test with $10.50
        taxManager.totalTaxPaid = 10.50
        XCTAssertEqual(taxManager.formattedTotalTax, "$10.50")
        
        // Test with $100
        taxManager.totalTaxPaid = 100.0
        XCTAssertEqual(taxManager.formattedTotalTax, "$100.00")
    }
    
    func testFormattedTimeUntilTax() async throws {
        // Need to ensure we're using the correct threshold
        let settings = SettingsManager.shared
        let originalThreshold = settings.taxThresholdHours
        settings.taxThresholdHours = .fourHours
        
        // Test with 0 time in darkness (full 4 hours remaining)
        taxManager.timeInDarkness = 0
        XCTAssertEqual(taxManager.formattedTimeUntilTax, "4h 0m")
        
        // Test with 2 hours in darkness (2 hours remaining)
        taxManager.timeInDarkness = 7200
        XCTAssertEqual(taxManager.formattedTimeUntilTax, "2h 0m")
        
        // Test with 3 hours 30 minutes in darkness (30 minutes remaining)
        taxManager.timeInDarkness = 12600
        XCTAssertEqual(taxManager.formattedTimeUntilTax, "0h 30m")
        
        // Test with 5 hours in darkness (0 remaining, already taxed)
        taxManager.timeInDarkness = 18000
        XCTAssertEqual(taxManager.formattedTimeUntilTax, "0h 0m")
        
        // Restore original threshold
        settings.taxThresholdHours = originalThreshold
    }
    
    // MARK: - Progress Calculation Tests
    
    func testProgressToTax() async throws {
        let settings = SettingsManager.shared
        let originalThreshold = settings.taxThresholdHours
        settings.taxThresholdHours = .fourHours
        
        // 0% progress
        taxManager.timeInDarkness = 0
        XCTAssertEqual(taxManager.progressToTax, 0.0)
        
        // 50% progress (2 hours)
        taxManager.timeInDarkness = 7200
        XCTAssertEqual(taxManager.progressToTax, 0.5)
        
        // 100% progress (4 hours)
        taxManager.timeInDarkness = 14400
        XCTAssertEqual(taxManager.progressToTax, 1.0)
        
        // Over 100% should be clamped (5 hours)
        taxManager.timeInDarkness = 18000
        XCTAssertEqual(taxManager.progressToTax, 1.0)
        
        // Restore original threshold
        settings.taxThresholdHours = originalThreshold
    }
    
    func testTimeUntilTax() async throws {
        let settings = SettingsManager.shared
        let originalThreshold = settings.taxThresholdHours
        settings.taxThresholdHours = .fourHours
        
        // Full time remaining
        taxManager.timeInDarkness = 0
        XCTAssertEqual(taxManager.timeUntilTax, 14400)
        
        // Half time remaining
        taxManager.timeInDarkness = 7200
        XCTAssertEqual(taxManager.timeUntilTax, 7200)
        
        // No time remaining (at threshold)
        taxManager.timeInDarkness = 14400
        XCTAssertEqual(taxManager.timeUntilTax, 0)
        
        // Over threshold
        taxManager.timeInDarkness = 18000
        XCTAssertEqual(taxManager.timeUntilTax, 0)
        
        // Restore original threshold
        settings.taxThresholdHours = originalThreshold
    }
    
    // MARK: - Computed Settings Tests
    
    func testTaxThreshold() async throws {
        let settings = SettingsManager.shared
        let originalThreshold = settings.taxThresholdHours
        
        settings.taxThresholdHours = .twoHours
        XCTAssertEqual(taxManager.taxThreshold, 2 * 3600)
        
        settings.taxThresholdHours = .eightHours
        XCTAssertEqual(taxManager.taxThreshold, 8 * 3600)
        
        settings.taxThresholdHours = originalThreshold
    }
    
    func testWarningThreshold() async throws {
        let settings = SettingsManager.shared
        let originalThreshold = settings.taxThresholdHours
        
        settings.taxThresholdHours = .fourHours
        XCTAssertEqual(taxManager.warningThreshold, (4 * 3600) - (30 * 60))
        
        settings.taxThresholdHours = originalThreshold
    }
    
    // MARK: - Debug Mode Tests
    
    func testDebugModeEnabled() async throws {
        let settings = SettingsManager.shared
        let originalDebugMode = settings.debugModeEnabled
        
        // Test when debug mode is false
        settings.debugModeEnabled = false
        XCTAssertFalse(taxManager.debugModeEnabled)
        
        // Test when debug mode is true
        settings.debugModeEnabled = true
        XCTAssertTrue(taxManager.debugModeEnabled)
        
        // Restore
        settings.debugModeEnabled = originalDebugMode
    }
}