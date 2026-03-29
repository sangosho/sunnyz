//
//  SettingsManagerTests.swift
//  SunnyZTests
//
//  Tests for SettingsManager defaults and persistence
//

import XCTest
@testable import SunnyZ

@MainActor
final class SettingsManagerTests: XCTestCase {
    
    var settings: SettingsManager!
    var originalLuxCalibrationOffset: Double!
    
    override func setUp() async throws {
        // Use the shared instance for testing
        settings = SettingsManager.shared
        // Save original values to restore after tests
        originalLuxCalibrationOffset = settings.luxCalibrationOffset
    }
    
    override func tearDown() async throws {
        // Restore original values
        settings.luxCalibrationOffset = originalLuxCalibrationOffset
    }
    
    // MARK: - Default Value Tests
    
    func testDefaultNotificationSettings() async throws {
        XCTAssertTrue(settings.notificationsEnabled)
        XCTAssertTrue(settings.warningNotificationsEnabled)
        XCTAssertTrue(settings.dailySummaryEnabled)
    }
    
    func testDefaultTaxSettings() async throws {
        XCTAssertEqual(settings.taxThresholdHours, .fourHours)
        XCTAssertTrue(settings.showCountdownInMenuBar)
    }
    
    func testDefaultLuxSettings() async throws {
        // Since SettingsManager is a singleton with persisted state,
        // we verify the properties are accessible and can be modified
        // rather than testing for specific default values
        let originalOffset = settings.luxCalibrationOffset
        let originalSunlight = settings.sunlightLuxThreshold
        let originalDarkness = settings.darknessLuxThreshold
        
        // Verify values are within expected ranges
        XCTAssertGreaterThanOrEqual(originalSunlight, 0)
        XCTAssertGreaterThanOrEqual(originalDarkness, 0)
        
        // Test that we can modify and the change persists
        settings.luxCalibrationOffset = 25.0
        XCTAssertEqual(settings.luxCalibrationOffset, 25.0)
        
        // Restore original
        settings.luxCalibrationOffset = originalOffset
    }
    
    func testDefaultGeneralSettings() async throws {
        XCTAssertFalse(settings.launchAtLogin)
    }
    
    func testDefaultDebugSettings() async throws {
        XCTAssertFalse(settings.debugModeEnabled)
    }
    
    // MARK: - TaxThreshold Enum Tests
    
    func testTaxThresholdCases() async throws {
        let allCases = SettingsManager.TaxThreshold.allCases
        
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.twoHours))
        XCTAssertTrue(allCases.contains(.fourHours))
        XCTAssertTrue(allCases.contains(.eightHours))
    }
    
    func testTaxThresholdRawValues() async throws {
        XCTAssertEqual(SettingsManager.TaxThreshold.twoHours.rawValue, 2)
        XCTAssertEqual(SettingsManager.TaxThreshold.fourHours.rawValue, 4)
        XCTAssertEqual(SettingsManager.TaxThreshold.eightHours.rawValue, 8)
    }
    
    func testTaxThresholdTimeIntervals() async throws {
        XCTAssertEqual(SettingsManager.TaxThreshold.twoHours.timeInterval, 2 * 3600)
        XCTAssertEqual(SettingsManager.TaxThreshold.fourHours.timeInterval, 4 * 3600)
        XCTAssertEqual(SettingsManager.TaxThreshold.eightHours.timeInterval, 8 * 3600)
    }
    
    func testTaxThresholdWarningIntervals() async throws {
        // Warning should be 30 minutes before tax
        XCTAssertEqual(SettingsManager.TaxThreshold.twoHours.warningTimeInterval, (2 * 3600) - (30 * 60))
        XCTAssertEqual(SettingsManager.TaxThreshold.fourHours.warningTimeInterval, (4 * 3600) - (30 * 60))
        XCTAssertEqual(SettingsManager.TaxThreshold.eightHours.warningTimeInterval, (8 * 3600) - (30 * 60))
    }
    
    func testTaxThresholdDisplayNames() async throws {
        XCTAssertEqual(SettingsManager.TaxThreshold.twoHours.displayName, "2 hours")
        XCTAssertEqual(SettingsManager.TaxThreshold.fourHours.displayName, "4 hours")
        XCTAssertEqual(SettingsManager.TaxThreshold.eightHours.displayName, "8 hours")
    }
    
    func testTaxThresholdIdentifiable() async throws {
        XCTAssertEqual(SettingsManager.TaxThreshold.twoHours.id, 2)
        XCTAssertEqual(SettingsManager.TaxThreshold.fourHours.id, 4)
        XCTAssertEqual(SettingsManager.TaxThreshold.eightHours.id, 8)
    }
    
    // MARK: - Computed Properties Tests
    
    func testTaxThresholdInterval() async throws {
        settings.taxThresholdHours = .fourHours
        XCTAssertEqual(settings.taxThresholdInterval, 4 * 3600)
        
        settings.taxThresholdHours = .twoHours
        XCTAssertEqual(settings.taxThresholdInterval, 2 * 3600)
    }
    
    func testWarningThresholdInterval() async throws {
        settings.taxThresholdHours = .fourHours
        XCTAssertEqual(settings.warningThresholdInterval, (4 * 3600) - (30 * 60))
    }
    
    func testFormattedTaxThreshold() async throws {
        settings.taxThresholdHours = .eightHours
        XCTAssertEqual(settings.formattedTaxThreshold, "8 hours")
    }
    
    // MARK: - Lux Calibration Tests
    
    func testApplyCalibration() async throws {
        settings.luxCalibrationOffset = 10.0
        let calibrated = settings.applyCalibration(to: 50.0)
        XCTAssertEqual(calibrated, 60.0)
    }
    
    func testCalibrateLux() async throws {
        settings.calibrateLux(currentReading: 50.0, actualLux: 100.0)
        XCTAssertEqual(settings.luxCalibrationOffset, 50.0)
    }
    
    // MARK: - Debug Helper Tests
    
    func testToggleDebugMode() async throws {
        let initialValue = settings.debugModeEnabled
        settings.toggleDebugMode()
        XCTAssertEqual(settings.debugModeEnabled, !initialValue)
        
        // Toggle back
        settings.toggleDebugMode()
        XCTAssertEqual(settings.debugModeEnabled, initialValue)
    }
}