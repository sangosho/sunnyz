//
//  AchievementTests.swift
//  SunnyZTests
//
//  Tests for Achievement model and related logic
//

import XCTest
@testable import SunnyZ

@MainActor
final class AchievementTests: XCTestCase {
    
    // MARK: - Codable Tests
    
    func testAchievementEncodingDecoding() async throws {
        let achievement = Achievement(
            id: "test-achievement",
            icon: "🧪",
            title: "Test Achievement",
            description: "A test achievement",
            category: .caveDwelling,
            condition: .vampireDarkness(hours: 5),
            isUnlocked: false,
            progress: 0.5
        )
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let data = try encoder.encode(achievement)
        let decoded = try decoder.decode(Achievement.self, from: data)
        
        XCTAssertEqual(decoded.id, achievement.id)
        XCTAssertEqual(decoded.icon, achievement.icon)
        XCTAssertEqual(decoded.title, achievement.title)
        XCTAssertEqual(decoded.description, achievement.description)
        XCTAssertEqual(decoded.category, achievement.category)
        XCTAssertEqual(decoded.isUnlocked, achievement.isUnlocked)
        XCTAssertEqual(decoded.progress, achievement.progress)
    }
    
    func testAchievementConditionEquatable() async throws {
        let condition1 = Achievement.AchievementCondition.vampireDarkness(hours: 24)
        let condition2 = Achievement.AchievementCondition.vampireDarkness(hours: 24)
        let condition3 = Achievement.AchievementCondition.vampireDarkness(hours: 12)
        let condition4 = Achievement.AchievementCondition.touchGrass
        
        XCTAssertEqual(condition1, condition2)
        XCTAssertNotEqual(condition1, condition3)
        XCTAssertNotEqual(condition1, condition4)
    }
    
    func testAllAchievementsContainsExpectedIDs() async throws {
        let allAchievements = Achievement.allAchievements
        
        let expectedIDs = [
            "vampire",
            "caveTroll",
            "nightOwl",
            "hermit",
            "diamondHands",
            "bigSpender",
            "touchGrass"
        ]
        
        let actualIDs = allAchievements.map { $0.id }
        
        for expectedID in expectedIDs {
            XCTAssertTrue(actualIDs.contains(expectedID), "Missing achievement: \(expectedID)")
        }
        
        XCTAssertEqual(allAchievements.count, 7)
    }
    
    func testAchievementCategories() async throws {
        let caveAchievements = Achievement.allAchievements.filter { $0.category == .caveDwelling }
        let financialAchievements = Achievement.allAchievements.filter { $0.category == .financial }
        let specialAchievements = Achievement.allAchievements.filter { $0.category == .special }
        
        XCTAssertEqual(caveAchievements.count, 4)
        XCTAssertEqual(financialAchievements.count, 2)
        XCTAssertEqual(specialAchievements.count, 1)
    }
    
    // MARK: - Helper Method Tests
    
    func testUnlockedMethod() async throws {
        let achievement = Achievement(
            id: "test",
            icon: "🔒",
            title: "Locked",
            description: "Not unlocked",
            category: .special,
            condition: .touchGrass,
            isUnlocked: false,
            progress: 0.0
        )
        
        let unlocked = achievement.unlocked()
        
        XCTAssertTrue(unlocked.isUnlocked)
        XCTAssertEqual(unlocked.progress, 1.0)
        XCTAssertNotNil(unlocked.unlockedAt)
    }
    
    func testWithProgressMethod() async throws {
        let achievement = Achievement(
            id: "test",
            icon: "📊",
            title: "Progress Test",
            description: "Testing progress",
            category: .special,
            condition: .touchGrass,
            isUnlocked: false,
            progress: 0.0
        )
        
        let withProgress = achievement.withProgress(0.75)
        
        XCTAssertEqual(withProgress.progress, 0.75)
        XCTAssertFalse(withProgress.isUnlocked) // Original unchanged
    }
    
    func testWithProgressClamping() async throws {
        let achievement = Achievement(
            id: "test",
            icon: "📊",
            title: "Progress Test",
            description: "Testing progress clamping",
            category: .special,
            condition: .touchGrass,
            isUnlocked: false,
            progress: 0.5
        )
        
        let aboveMax = achievement.withProgress(1.5)
        let belowMin = achievement.withProgress(-0.5)
        
        XCTAssertEqual(aboveMax.progress, 1.0)
        XCTAssertEqual(belowMin.progress, 0.0)
    }
    
    // MARK: - Achievement Condition Tests
    
    func testVampireDarknessCondition() async throws {
        let condition = Achievement.AchievementCondition.vampireDarkness(hours: 24)
        
        if case .vampireDarkness(let hours) = condition {
            XCTAssertEqual(hours, 24)
        } else {
            XCTFail("Expected vampireDarkness condition")
        }
    }
    
    func testCaveTrollCondition() async throws {
        let condition = Achievement.AchievementCondition.caveTrollDays(days: 7, dailyHours: 12)
        
        if case .caveTrollDays(let days, let dailyHours) = condition {
            XCTAssertEqual(days, 7)
            XCTAssertEqual(dailyHours, 12)
        } else {
            XCTFail("Expected caveTrollDays condition")
        }
    }
    
    func testDiamondHandsCondition() async throws {
        let condition = Achievement.AchievementCondition.diamondHands(payments: 10)
        
        if case .diamondHands(let payments) = condition {
            XCTAssertEqual(payments, 10)
        } else {
            XCTFail("Expected diamondHands condition")
        }
    }
    
    func testBigSpenderCondition() async throws {
        let condition = Achievement.AchievementCondition.bigSpender(amount: 10.0)
        
        if case .bigSpender(let amount) = condition {
            XCTAssertEqual(amount, 10.0)
        } else {
            XCTFail("Expected bigSpender condition")
        }
    }
    
    func testHermitCondition() async throws {
        let condition = Achievement.AchievementCondition.hermitDays(days: 30)
        
        if case .hermitDays(let days) = condition {
            XCTAssertEqual(days, 30)
        } else {
            XCTFail("Expected hermitDays condition")
        }
    }
    
    func testNightOwlCondition() async throws {
        let condition = Achievement.AchievementCondition.nightOwlDays(days: 3, startHour: 22, endHour: 6)
        
        if case .nightOwlDays(let days, let startHour, let endHour) = condition {
            XCTAssertEqual(days, 3)
            XCTAssertEqual(startHour, 22)
            XCTAssertEqual(endHour, 6)
        } else {
            XCTFail("Expected nightOwlDays condition")
        }
    }
    
    func testTouchGrassCondition() async throws {
        let condition = Achievement.AchievementCondition.touchGrass
        
        if case .touchGrass = condition {
            // Success
        } else {
            XCTFail("Expected touchGrass condition")
        }
    }
}