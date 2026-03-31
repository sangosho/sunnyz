//
//  SnarkManager.swift
//  SunnyZ
//
//  Snarky reminder engine - generates context-aware messages at 3 snark levels
//

import Foundation
import UserNotifications

/// Manages snarky "Go Outside" reminders with configurable levels and intervals
@MainActor
final class SnarkManager: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = SnarkManager()
    
    // MARK: - Published State
    @Published var lastReminderTime: Date?
    @Published var snarkLevel: SnarkLevel {
        didSet { saveSnarkLevel() }
    }
    @Published var reminderInterval: ReminderInterval {
        didSet { 
            saveReminderInterval()
            rescheduleReminders()
        }
    }
    @Published var remindersEnabled: Bool {
        didSet { 
            saveRemindersEnabled()
            if remindersEnabled {
                rescheduleReminders()
            } else {
                cancelReminders()
            }
        }
    }
    
    // MARK: - Enums
    
    enum SnarkLevel: Int, CaseIterable, Identifiable {
        case mild = 0
        case medium = 1
        case savage = 2
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .mild: return "Mild"
            case .medium: return "Medium"
            case .savage: return "Savage"
            }
        }
        
        var description: String {
            switch self {
            case .mild: return "Gentle nudges"
            case .medium: return "Playful guilt"
            case .savage: return "Full roast mode"
            }
        }
        
        var emoji: String {
            switch self {
            case .mild: return "😊"
            case .medium: return "😏"
            case .savage: return "🔥"
            }
        }
    }
    
    enum ReminderInterval: Int, CaseIterable, Identifiable {
        case off = 0
        case fifteenMinutes = 15
        case thirtyMinutes = 30
        case oneHour = 60
        case twoHours = 120
        case fourHours = 240
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .off: return "Off"
            case .fifteenMinutes: return "15 min"
            case .thirtyMinutes: return "30 min"
            case .oneHour: return "1 hour"
            case .twoHours: return "2 hours"
            case .fourHours: return "4 hours"
            }
        }
        
        var timeInterval: TimeInterval? {
            if self == .off { return nil }
            return TimeInterval(rawValue * 60)
        }
    }
    
    // MARK: - Message Library
    
    private let mildMessages = [
        "Your plants are judging you silently",
        "Maybe a quick walk? No pressure",
        "The sun's still out there, just saying",
        "A little vitamin D never hurt anyone",
        "Fresh air is free (unlike this app)"
    ]
    
    private let mediumMessages = [
        "Your chair has a permanent imprint of you",
        "The outdoors is calling. You're ignoring it.",
        "Your skin is becoming translucent",
        "Touch grass™ - limited time offer",
        "Your cave is impressive. Too impressive."
    ]
    
    private let savageMessages = [
        "Your ancestors survived outdoors so you could... do this?",
        "Even Minecraft characters go outside more",
        "Your vitamin D deficiency has a deficiency",
        "The sun filed a restraining order",
        "You're one with the chair now. Congratulations."
    ]
    
    // MARK: - Private Properties
    
    private var shownMessageIndices: [SnarkLevel: Set<Int>] = [:]
    // `nonisolated(unsafe)` allows deinit (which is nonisolated in Swift 6)
    // to invalidate the timer without a MainActor hop. All other accesses to
    // this property happen on the MainActor, so the lack of isolation checks
    // here is safe in practice.
    private nonisolated(unsafe) var reminderTimer: Timer?
    private var lastShownMessage: String?
    private var currentSessionMessages: [String] = []
    
    // UserDefaults keys
    private let kSnarkLevel = "sunnyz.snark.level"
    private let kReminderInterval = "sunnyz.snark.reminderInterval"
    private let kRemindersEnabled = "sunnyz.snark.remindersEnabled"
    private let kLastReminderTime = "sunnyz.snark.lastReminderTime"
    private let kShownMessageIndices = "sunnyz.snark.shownMessageIndices"
    
    // MARK: - Initialization
    
    private init() {
        let defaults = UserDefaults.standard
        
        // Load settings
        if let levelRaw = defaults.object(forKey: kSnarkLevel) as? Int,
           let level = SnarkLevel(rawValue: levelRaw) {
            self.snarkLevel = level
        } else {
            self.snarkLevel = .medium
        }
        
        if let intervalRaw = defaults.object(forKey: kReminderInterval) as? Int,
           let interval = ReminderInterval(rawValue: intervalRaw) {
            self.reminderInterval = interval
        } else {
            self.reminderInterval = .oneHour
        }
        
        self.remindersEnabled = defaults.object(forKey: kRemindersEnabled) as? Bool ?? true
        
        if let lastTime = defaults.object(forKey: kLastReminderTime) as? Date {
            self.lastReminderTime = lastTime
        }
        
        // Load shown message indices
        if let savedIndices = defaults.object(forKey: kShownMessageIndices) as? [String: [Int]] {
            for (key, indices) in savedIndices {
                if let level = SnarkLevel(rawValue: Int(key) ?? 0) {
                    shownMessageIndices[level] = Set(indices)
                }
            }
        }
        
        // Start reminder scheduling if enabled
        if remindersEnabled && reminderInterval != .off {
            scheduleReminders()
        }
        
        // Listen for sunlight detection to reset
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSunlightDetected),
            name: .sunlightDetected,
            object: nil
        )
    }
    
    deinit {
        reminderTimer?.invalidate()
        reminderTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Message Generation
    
    /// Gets a snarky message appropriate for the current level
    func getSnarkyMessage(for level: SnarkLevel? = nil) -> String {
        let targetLevel = level ?? snarkLevel
        let messages = messagesForLevel(targetLevel)
        
        // Get shown indices for this level
        var shown = shownMessageIndices[targetLevel] ?? Set<Int>()
        
        // If all messages shown, reset
        if shown.count >= messages.count {
            shown.removeAll()
        }
        
        // Get available indices
        let availableIndices = Set(0..<messages.count).subtracting(shown)
        
        // Pick random available message
        guard let randomIndex = availableIndices.randomElement() else {
            return messages.randomElement() ?? "Go outside!"
        }
        
        // Mark as shown
        shown.insert(randomIndex)
        shownMessageIndices[targetLevel] = shown
        saveShownMessageIndices()
        
        let message = messages[randomIndex]
        lastShownMessage = message
        return message
    }
    
    /// Gets a preview message for the given level without affecting rotation
    func previewMessage(for level: SnarkLevel) -> String {
        let messages = messagesForLevel(level)
        return messages.randomElement() ?? "Go outside!"
    }
    
    private func messagesForLevel(_ level: SnarkLevel) -> [String] {
        switch level {
        case .mild: return mildMessages
        case .medium: return mediumMessages
        case .savage: return savageMessages
        }
    }
    
    // MARK: - Reminder Scheduling
    
    func scheduleReminders() {
        cancelReminders()
        
        guard remindersEnabled, 
              reminderInterval != .off,
              let interval = reminderInterval.timeInterval else { return }
        
        // Create a repeating timer that fires at the specified interval
        reminderTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendReminderIfAppropriate()
            }
        }
        
        print("[SunnyZ] Scheduled snark reminders every \(reminderInterval.displayName)")
    }
    
    func cancelReminders() {
        reminderTimer?.invalidate()
        reminderTimer = nil
        print("[SunnyZ] Cancelled snark reminders")
    }
    
    func rescheduleReminders() {
        cancelReminders()
        if remindersEnabled && reminderInterval != .off {
            scheduleReminders()
        }
    }
    
    /// Sends a reminder notification if conditions are met
    func sendReminderIfAppropriate() {
        let taxManager = SunlightTaxManager.shared
        
        // Only show reminders when:
        // 1. In darkness (not sunlight)
        // 2. Not when already taxed (don't pile on)
        // 3. Notifications are enabled
        guard taxManager.taxStatus != .exempt,
              taxManager.taxStatus != .taxed,
              NotificationManager.shared.notificationsEnabled,
              NotificationManager.shared.isAuthorized else { return }
        
        let message = getSnarkyMessage()
        sendReminderNotification(message: message)
        
        lastReminderTime = Date()
        UserDefaults.standard.set(Date(), forKey: kLastReminderTime)
    }
    
    /// Sends a reminder notification immediately (for testing)
    func sendTestReminder() {
        let message = getSnarkyMessage()
        sendReminderNotification(message: message, isTest: true)
        lastReminderTime = Date()
        UserDefaults.standard.set(Date(), forKey: kLastReminderTime)
    }
    
    private func sendReminderNotification(message: String, isTest: Bool = false) {
        guard Bundle.main.bundlePath.hasSuffix(".app") else { return }

        let content = UNMutableNotificationContent()
        content.title = isTest ? "🧪 Test Reminder" : "☀️ Go Outside!"
        content.body = message
        content.sound = .default
        content.badge = 1
        
        // Add snark level indicator
        switch snarkLevel {
        case .mild:
            content.subtitle = "Gentle reminder"
        case .medium:
            content.subtitle = "You should probably listen..."
        case .savage:
            content.subtitle = "No holding back"
        }
        
        let request = UNNotificationRequest(
            identifier: "sunnyz.snark.\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send snark reminder: \(error)")
            } else {
                print("[SunnyZ] Sent snark reminder: \(message)")
            }
        }
    }
    
    // MARK: - Event Handlers
    
    @objc private func handleSunlightDetected() {
        // Reset shown messages when user goes outside
        shownMessageIndices.removeAll()
        saveShownMessageIndices()
        currentSessionMessages.removeAll()
        
        // Don't reset lastReminderTime - we want to track when they last got nagged
    }
    
    // MARK: - Persistence
    
    private func saveSnarkLevel() {
        UserDefaults.standard.set(snarkLevel.rawValue, forKey: kSnarkLevel)
    }
    
    private func saveReminderInterval() {
        UserDefaults.standard.set(reminderInterval.rawValue, forKey: kReminderInterval)
    }
    
    private func saveRemindersEnabled() {
        UserDefaults.standard.set(remindersEnabled, forKey: kRemindersEnabled)
    }
    
    private func saveShownMessageIndices() {
        var dict: [String: [Int]] = [:]
        for (level, indices) in shownMessageIndices {
            dict[String(level.rawValue)] = Array(indices)
        }
        UserDefaults.standard.set(dict, forKey: kShownMessageIndices)
    }
    
    // MARK: - Formatting
    
    var formattedLastReminderTime: String {
        guard let lastTime = lastReminderTime else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastTime, relativeTo: Date())
    }
    
    var nextReminderDescription: String {
        guard remindersEnabled, reminderInterval != .off else {
            return "Reminders off"
        }
        
        guard let lastTime = lastReminderTime,
              let interval = reminderInterval.timeInterval else {
            return "Next: soon"
        }
        
        let nextTime = lastTime.addingTimeInterval(interval)
        let timeUntil = nextTime.timeIntervalSince(Date())
        
        if timeUntil <= 0 {
            return "Next: soon"
        }
        
        let minutes = Int(timeUntil) / 60
        if minutes < 60 {
            return "Next: in \(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "Next: in \(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let sunlightDetected = Notification.Name("sunnyz.sunlightDetected")
}
