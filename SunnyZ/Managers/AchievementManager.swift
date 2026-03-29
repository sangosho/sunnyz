//
//  AchievementManager.swift
//  SunnyZ
//
//  Manages achievement tracking, unlocking, and persistence
//

import Foundation
import Combine
import UserNotifications

/// Manages achievements for the SunnyZ app
@MainActor
final class AchievementManager: ObservableObject {
    static let shared = AchievementManager()

    // MARK: - Published State

    @Published var achievements: [Achievement] = []
    @Published var recentlyUnlocked: [Achievement] = []
    @Published var totalUnlocked: Int = 0
    @Published var showConfetti: Bool = false

    // MARK: - Private Properties

    private let kAchievements = "sunlightTax.achievements"
    private let kNightOwlDates = "sunlightTax.nightOwlDates"
    private let kCaveTrollDates = "sunlightTax.caveTrollDates"
    private let kHermitStartDate = "sunlightTax.hermitStartDate"
    private let kTaxPaymentCount = "sunlightTax.taxPaymentCount"

    // Tracking state
    private var nightOwlDates: Set<Date> = []
    private var caveTrollDates: Set<Date> = []
    private var hermitStartDate: Date?

    // MARK: - Initialization

    private init() {
        loadAchievements()
        loadTrackingData()
        totalUnlocked = achievements.filter { $0.isUnlocked }.count
    }

    // MARK: - Persistence

    private func loadAchievements() {
        if let data = UserDefaults.standard.data(forKey: kAchievements),
           let decoded = try? JSONDecoder().decode([Achievement].self, from: data) {
            achievements = decoded
        } else {
            // Initialize with all achievements locked
            achievements = Achievement.allAchievements.map { achievement in
                var updated = achievement
                updated.isUnlocked = false
                updated.progress = 0.0
                return updated
            }
        }
    }

    func saveAchievements() {
        if let encoded = try? JSONEncoder().encode(achievements) {
            UserDefaults.standard.set(encoded, forKey: kAchievements)
        }
    }

    private func loadTrackingData() {
        // Load night owl dates (stored as date strings)
        if let dateStrings = UserDefaults.standard.stringArray(forKey: kNightOwlDates) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            nightOwlDates = Set(dateStrings.compactMap { formatter.date(from: $0) })
        }

        // Load cave troll dates
        if let dateStrings = UserDefaults.standard.stringArray(forKey: kCaveTrollDates) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            caveTrollDates = Set(dateStrings.compactMap { formatter.date(from: $0) })
        }

        // Load hermit start date
        if let date = UserDefaults.standard.object(forKey: kHermitStartDate) as? Date {
            hermitStartDate = date
        }
    }

    private func saveTrackingData() {
        // Save night owl dates
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let nightOwlStrings = nightOwlDates.map { formatter.string(from: $0) }
        UserDefaults.standard.set(nightOwlStrings, forKey: kNightOwlDates)

        // Save cave troll dates
        let caveTrollStrings = caveTrollDates.map { formatter.string(from: $0) }
        UserDefaults.standard.set(caveTrollStrings, forKey: kCaveTrollDates)

        // Save hermit start date
        if let date = hermitStartDate {
            UserDefaults.standard.set(date, forKey: kHermitStartDate)
        } else {
            UserDefaults.standard.removeObject(forKey: kHermitStartDate)
        }
    }

    // MARK: - Achievement Checking

    /// Check and update achievements based on current state
    func checkAchievements(
        timeInDarkness: TimeInterval,
        totalTaxPaid: Double,
        taxPaymentCount: Int,
        lastSunlightDate: Date?,
        isTaxed: Bool
    ) {
        var updated = false

        // Check each achievement
        for index in achievements.indices {
            let achievement = achievements[index]

            // Skip already unlocked
            if achievement.isUnlocked {
                continue
            }

            let (shouldUnlock, progress) = evaluateCondition(
                achievement.condition,
                timeInDarkness: timeInDarkness,
                totalTaxPaid: totalTaxPaid,
                taxPaymentCount: taxPaymentCount,
                lastSunlightDate: lastSunlightDate,
                isTaxed: isTaxed
            )

            // Update progress
            if achievements[index].progress != progress {
                achievements[index] = achievements[index].withProgress(progress)
                updated = true
            }

            // Unlock if condition met
            if shouldUnlock {
                unlockAchievement(at: index)
                updated = true
            }
        }

        if updated {
            saveAchievements()
            totalUnlocked = achievements.filter { $0.isUnlocked }.count
        }
    }

    /// Handle going outside (sunlight detected)
    func handleWentOutside(timeInDarkness: TimeInterval) {
        // Touch Grass achievement: Go outside after 4h+ darkness
        if timeInDarkness >= 4 * 3600 {
            if let index = achievements.firstIndex(where: { $0.id == "touchGrass" }),
               !achievements[index].isUnlocked {
                unlockAchievement(at: index)
                saveAchievements()

                // Trigger confetti
                showConfetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self.showConfetti = false
                }
            }
        }

        // Reset hermit streak
        hermitStartDate = nil
        saveTrackingData()

        // Update hermit progress
        if let index = achievements.firstIndex(where: { $0.id == "hermit" }),
           !achievements[index].isUnlocked {
            achievements[index] = achievements[index].withProgress(0.0)
            saveAchievements()
        }
    }

    /// Handle tax payment
    func handleTaxPayment() {
        // Track cave troll date (daily darkness)
        let today = Calendar.current.startOfDay(for: Date())
        caveTrollDates.insert(today)
        saveTrackingData()

        // Save payment count
        let currentCount = UserDefaults.standard.integer(forKey: kTaxPaymentCount) + 1
        UserDefaults.standard.set(currentCount, forKey: kTaxPaymentCount)
    }

    /// Track night owl activity (call when app is used between 10pm-6am)
    func trackNightOwlActivity() {
        let hour = Calendar.current.component(.hour, from: Date())

        // Night owl hours: 10pm-6am (22:00 - 06:00)
        if hour >= 22 || hour < 6 {
            let today = Calendar.current.startOfDay(for: Date())
            nightOwlDates.insert(today)
            saveTrackingData()
        }
    }

    /// Track cave troll daily darkness
    func trackDailyDarkness(dailyDarknessSeconds: TimeInterval) {
        if dailyDarknessSeconds >= 12 * 3600 { // 12 hours
            let today = Calendar.current.startOfDay(for: Date())
            caveTrollDates.insert(today)
            saveTrackingData()
        }
    }

    // MARK: - Private Helpers

    private func unlockAchievement(at index: Int) {
        achievements[index] = achievements[index].unlocked()
        recentlyUnlocked.append(achievements[index])

        // Limit recently unlocked to last 5
        if recentlyUnlocked.count > 5 {
            recentlyUnlocked.removeFirst()
        }

        // Send notification
        sendAchievementNotification(achievements[index])
    }

    private func evaluateCondition(
        _ condition: Achievement.AchievementCondition,
        timeInDarkness: TimeInterval,
        totalTaxPaid: Double,
        taxPaymentCount: Int,
        lastSunlightDate: Date?,
        isTaxed: Bool
    ) -> (Bool, Double) {
        switch condition {
        case .vampireDarkness(let hours):
            let requiredSeconds = Double(hours) * 3600
            let progress = timeInDarkness / requiredSeconds
            return (timeInDarkness >= requiredSeconds, progress)

        case .caveTrollDays(let days, let dailyHours):
            let requiredDays = days
            let progress = Double(caveTrollDates.count) / Double(requiredDays)
            return (caveTrollDates.count >= requiredDays, progress)

        case .diamondHands(let payments):
            let progress = Double(taxPaymentCount) / Double(payments)
            return (taxPaymentCount >= payments, progress)

        case .hermitDays(let days):
            // Hermit tracks consecutive days without sunlight
            var streak = 0
            if let startDate = hermitStartDate {
                streak = Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
            } else if lastSunlightDate == nil {
                hermitStartDate = Date()
                streak = 1
            }
            let progress = Double(streak) / Double(days)
            return (streak >= days, progress)

        case .nightOwlDays(let days, let startHour, let endHour):
            let progress = Double(nightOwlDates.count) / Double(days)
            return (nightOwlDates.count >= days, progress)

        case .bigSpender(let amount):
            let progress = totalTaxPaid / amount
            return (totalTaxPaid >= amount, progress)

        case .touchGrass:
            // This is handled separately in handleWentOutside
            return (false, 0.0)
        }
    }

    private func sendAchievementNotification(_ achievement: Achievement) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }

        let content = UNMutableNotificationContent()
        content.title = "Achievement Unlocked! 🏆"
        content.body = "\(achievement.icon) \(achievement.title)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "achievement-\(achievement.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send achievement notification: \(error)")
            }
        }
    }

    // MARK: - Reset

    func resetAchievements() {
        achievements = Achievement.allAchievements.map { achievement in
            var updated = achievement
            updated.isUnlocked = false
            updated.progress = 0.0
            return updated
        }

        nightOwlDates.removeAll()
        caveTrollDates.removeAll()
        hermitStartDate = nil

        saveAchievements()
        saveTrackingData()
        totalUnlocked = 0
        recentlyUnlocked.removeAll()
    }

    // MARK: - Helpers

    /// Get achievement by ID
    func achievement(for id: String) -> Achievement? {
        achievements.first { $0.id == id }
    }

    /// Get achievements by category
    func achievements(in category: Achievement.AchievementCategory) -> [Achievement] {
        achievements.filter { $0.category == category }
    }

    /// Get total progress percentage
    var overallProgress: Double {
        let totalProgress = achievements.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(achievements.count)
    }

    /// Get achievement share text
    func shareText(for achievement: Achievement) -> String {
        return "I just unlocked the \"\(achievement.icon) \(achievement.title)\" achievement in SunnyZ! \(achievement.description) #TouchGrass"
    }
}
