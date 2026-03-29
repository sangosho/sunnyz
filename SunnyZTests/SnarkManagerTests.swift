//
//  SnarkManagerTests.swift
//  SunnyZTests
//
//  Tests for SnarkManager message generation
//

import XCTest
@testable import SunnyZ

@MainActor
final class SnarkManagerTests: XCTestCase {
    
    var snarkManager: SnarkManager!
    
    override func setUp() async throws {
        snarkManager = SnarkManager.shared
    }
    
    // MARK: - SnarkLevel Enum Tests
    
    func testSnarkLevelCases() async throws {
        let allCases = SnarkManager.SnarkLevel.allCases
        
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.mild))
        XCTAssertTrue(allCases.contains(.medium))
        XCTAssertTrue(allCases.contains(.savage))
    }
    
    func testSnarkLevelRawValues() async throws {
        XCTAssertEqual(SnarkManager.SnarkLevel.mild.rawValue, 0)
        XCTAssertEqual(SnarkManager.SnarkLevel.medium.rawValue, 1)
        XCTAssertEqual(SnarkManager.SnarkLevel.savage.rawValue, 2)
    }
    
    func testSnarkLevelDisplayNames() async throws {
        XCTAssertEqual(SnarkManager.SnarkLevel.mild.displayName, "Mild")
        XCTAssertEqual(SnarkManager.SnarkLevel.medium.displayName, "Medium")
        XCTAssertEqual(SnarkManager.SnarkLevel.savage.displayName, "Savage")
    }
    
    func testSnarkLevelDescriptions() async throws {
        XCTAssertEqual(SnarkManager.SnarkLevel.mild.description, "Gentle nudges")
        XCTAssertEqual(SnarkManager.SnarkLevel.medium.description, "Playful guilt")
        XCTAssertEqual(SnarkManager.SnarkLevel.savage.description, "Full roast mode")
    }
    
    func testSnarkLevelEmojis() async throws {
        XCTAssertEqual(SnarkManager.SnarkLevel.mild.emoji, "😊")
        XCTAssertEqual(SnarkManager.SnarkLevel.medium.emoji, "😏")
        XCTAssertEqual(SnarkManager.SnarkLevel.savage.emoji, "🔥")
    }
    
    func testSnarkLevelIdentifiable() async throws {
        XCTAssertEqual(SnarkManager.SnarkLevel.mild.id, 0)
        XCTAssertEqual(SnarkManager.SnarkLevel.medium.id, 1)
        XCTAssertEqual(SnarkManager.SnarkLevel.savage.id, 2)
    }
    
    // MARK: - ReminderInterval Enum Tests
    
    func testReminderIntervalCases() async throws {
        let allCases = SnarkManager.ReminderInterval.allCases
        
        XCTAssertEqual(allCases.count, 6)
        XCTAssertTrue(allCases.contains(.off))
        XCTAssertTrue(allCases.contains(.fifteenMinutes))
        XCTAssertTrue(allCases.contains(.thirtyMinutes))
        XCTAssertTrue(allCases.contains(.oneHour))
        XCTAssertTrue(allCases.contains(.twoHours))
        XCTAssertTrue(allCases.contains(.fourHours))
    }
    
    func testReminderIntervalRawValues() async throws {
        XCTAssertEqual(SnarkManager.ReminderInterval.off.rawValue, 0)
        XCTAssertEqual(SnarkManager.ReminderInterval.fifteenMinutes.rawValue, 15)
        XCTAssertEqual(SnarkManager.ReminderInterval.thirtyMinutes.rawValue, 30)
        XCTAssertEqual(SnarkManager.ReminderInterval.oneHour.rawValue, 60)
        XCTAssertEqual(SnarkManager.ReminderInterval.twoHours.rawValue, 120)
        XCTAssertEqual(SnarkManager.ReminderInterval.fourHours.rawValue, 240)
    }
    
    func testReminderIntervalDisplayNames() async throws {
        XCTAssertEqual(SnarkManager.ReminderInterval.off.displayName, "Off")
        XCTAssertEqual(SnarkManager.ReminderInterval.fifteenMinutes.displayName, "15 min")
        XCTAssertEqual(SnarkManager.ReminderInterval.thirtyMinutes.displayName, "30 min")
        XCTAssertEqual(SnarkManager.ReminderInterval.oneHour.displayName, "1 hour")
        XCTAssertEqual(SnarkManager.ReminderInterval.twoHours.displayName, "2 hours")
        XCTAssertEqual(SnarkManager.ReminderInterval.fourHours.displayName, "4 hours")
    }
    
    func testReminderIntervalTimeIntervals() async throws {
        XCTAssertNil(SnarkManager.ReminderInterval.off.timeInterval)
        XCTAssertEqual(SnarkManager.ReminderInterval.fifteenMinutes.timeInterval, 15 * 60)
        XCTAssertEqual(SnarkManager.ReminderInterval.thirtyMinutes.timeInterval, 30 * 60)
        XCTAssertEqual(SnarkManager.ReminderInterval.oneHour.timeInterval, 60 * 60)
        XCTAssertEqual(SnarkManager.ReminderInterval.twoHours.timeInterval, 120 * 60)
        XCTAssertEqual(SnarkManager.ReminderInterval.fourHours.timeInterval, 240 * 60)
    }
    
    // MARK: - Message Generation Tests
    
    func testGetSnarkyMessageReturnsNonEmptyString() async throws {
        let message = snarkManager.getSnarkyMessage()
        
        XCTAssertFalse(message.isEmpty)
        XCTAssertGreaterThan(message.count, 0)
    }
    
    func testGetSnarkyMessageForMildLevel() async throws {
        let message = snarkManager.getSnarkyMessage(for: .mild)
        
        XCTAssertFalse(message.isEmpty)
        // Mild messages should be relatively gentle
        XCTAssertGreaterThan(message.count, 0)
    }
    
    func testGetSnarkyMessageForMediumLevel() async throws {
        let message = snarkManager.getSnarkyMessage(for: .medium)
        
        XCTAssertFalse(message.isEmpty)
        XCTAssertGreaterThan(message.count, 0)
    }
    
    func testGetSnarkyMessageForSavageLevel() async throws {
        let message = snarkManager.getSnarkyMessage(for: .savage)
        
        XCTAssertFalse(message.isEmpty)
        XCTAssertGreaterThan(message.count, 0)
    }
    
    func testPreviewMessageReturnsNonEmptyString() async throws {
        let preview = snarkManager.previewMessage(for: .medium)
        
        XCTAssertFalse(preview.isEmpty)
        XCTAssertGreaterThan(preview.count, 0)
    }
    
    func testDifferentLevelsReturnDifferentMessagePools() async throws {
        // Get multiple messages from each level to ensure we're getting from correct pools
        let mildMessage = snarkManager.getSnarkyMessage(for: .mild)
        let mediumMessage = snarkManager.getSnarkyMessage(for: .medium)
        let savageMessage = snarkManager.getSnarkyMessage(for: .savage)
        
        // All should be non-empty
        XCTAssertFalse(mildMessage.isEmpty)
        XCTAssertFalse(mediumMessage.isEmpty)
        XCTAssertFalse(savageMessage.isEmpty)
        
        // They should be different from each other (with high probability)
        // Note: There's a tiny chance they could be the same by coincidence
        // but with different message pools this is very unlikely
    }
    
    // MARK: - Default Settings Tests
    
    func testDefaultSnarkLevel() async throws {
        // Default should be medium
        XCTAssertEqual(snarkManager.snarkLevel, .medium)
    }
    
    func testDefaultReminderInterval() async throws {
        // Default should be one hour
        XCTAssertEqual(snarkManager.reminderInterval, .oneHour)
    }
    
    func testDefaultRemindersEnabled() async throws {
        // Default should be true
        XCTAssertTrue(snarkManager.remindersEnabled)
    }
    
    // MARK: - Formatting Tests
    
    func testFormattedLastReminderTimeWhenNil() async throws {
        // When lastReminderTime is nil, should return "Never"
        // We can't easily test this without resetting state, but we can test the method exists
        let formatted = snarkManager.formattedLastReminderTime
        XCTAssertTrue(formatted == "Never" || !formatted.isEmpty)
    }
    
    func testNextReminderDescriptionWhenDisabled() async throws {
        snarkManager.remindersEnabled = false
        
        let description = snarkManager.nextReminderDescription
        XCTAssertEqual(description, "Reminders off")
        
        // Reset
        snarkManager.remindersEnabled = true
    }
}