//
//  Achievement.swift
//  SunnyZ
//
//  Achievement data model for tracking badges
//

import Foundation

/// Represents an achievement badge in SunnyZ
struct Achievement: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let icon: String
    let title: String
    let description: String
    let category: AchievementCategory
    let condition: AchievementCondition
    var isUnlocked: Bool
    var unlockedAt: Date?
    var progress: Double // 0.0 to 1.0

    enum AchievementCategory: String, Codable, Sendable {
        case caveDwelling = "Cave Dwelling"
        case financial = "Financial"
        case special = "Special"
    }

    enum AchievementCondition: Codable, Equatable, Sendable {
        case vampireDarkness(hours: Int)
        case caveTrollDays(days: Int, dailyHours: Int)
        case diamondHands(payments: Int)
        case hermitDays(days: Int)
        case nightOwlDays(days: Int, startHour: Int, endHour: Int)
        case bigSpender(amount: Double)
        case touchGrass
    }

    // All defined achievements
    static let allAchievements: [Achievement] = [
        // Cave Dwelling achievements
        Achievement(
            id: "vampire",
            icon: "🦇",
            title: "Vampire",
            description: "Stay in darkness for 24+ hours without sunlight",
            category: .caveDwelling,
            condition: .vampireDarkness(hours: 24),
            isUnlocked: false,
            progress: 0.0
        ),
        Achievement(
            id: "caveTroll",
            icon: "🧌",
            title: "Cave Troll",
            description: "Live as a cave troll for 7 days (12h+ darkness each day)",
            category: .caveDwelling,
            condition: .caveTrollDays(days: 7, dailyHours: 12),
            isUnlocked: false,
            progress: 0.0
        ),
        Achievement(
            id: "nightOwl",
            icon: "🌙",
            title: "Night Owl",
            description: "Be active only between 10pm-6am for 3 days",
            category: .caveDwelling,
            condition: .nightOwlDays(days: 3, startHour: 22, endHour: 6),
            isUnlocked: false,
            progress: 0.0
        ),
        Achievement(
            id: "hermit",
            icon: "🏠",
            title: "Hermit",
            description: "Go 30 days without going outside",
            category: .caveDwelling,
            condition: .hermitDays(days: 30),
            isUnlocked: false,
            progress: 0.0
        ),

        // Financial achievements
        Achievement(
            id: "diamondHands",
            icon: "💎",
            title: "Diamond Hands",
            description: "Pay the sunlight tax 10+ times",
            category: .financial,
            condition: .diamondHands(payments: 10),
            isUnlocked: false,
            progress: 0.0
        ),
        Achievement(
            id: "bigSpender",
            icon: "💸",
            title: "Big Spender",
            description: "Spend $10+ total on sunlight tax",
            category: .financial,
            condition: .bigSpender(amount: 10.0),
            isUnlocked: false,
            progress: 0.0
        ),

        // Special achievements
        Achievement(
            id: "touchGrass",
            icon: "☀️",
            title: "Touch Grass",
            description: "Actually go outside after 4h+ in darkness (rare!)",
            category: .special,
            condition: .touchGrass,
            isUnlocked: false,
            progress: 0.0
        )
    ]

    // Helper to create unlocked version
    func unlocked() -> Achievement {
        var updated = self
        updated.isUnlocked = true
        updated.unlockedAt = Date()
        updated.progress = 1.0
        return updated
    }

    // Helper to update progress
    func withProgress(_ newProgress: Double) -> Achievement {
        var updated = self
        updated.progress = min(max(newProgress, 0.0), 1.0)
        return updated
    }
}
