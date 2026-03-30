//
//  NotificationManager.swift
//  SunnyZ
//
//  User notification management - warnings, tax alerts, and daily summaries
//

import Foundation
import UserNotifications
import SwiftUI

/// Manages all user notifications for SunnyZ
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var isAuthorized = false
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: kNotificationsEnabled)
            if notificationsEnabled && !isAuthorized {
                requestAuthorization()
            }
        }
    }
    
    @Published var warningNotificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(warningNotificationsEnabled, forKey: kWarningNotificationsEnabled)
        }
    }
    
    @Published var dailySummaryEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dailySummaryEnabled, forKey: kDailySummaryEnabled)
            if dailySummaryEnabled {
                scheduleDailySummary()
            } else {
                cancelDailySummary()
            }
        }
    }
    
    @Published var dailySummaryTime: Date {
        didSet {
            UserDefaults.standard.set(dailySummaryTime, forKey: kDailySummaryTime)
            if dailySummaryEnabled {
                scheduleDailySummary()
            }
        }
    }
    
    // MARK: - Notification State Tracking
    
    private var hasShown30MinWarning = false
    private var hasShown5MinWarning = false
    private var hasShownTaxApplied = false
    private var lastTaxStatus: SunlightTaxManager.TaxStatus = .exempt
    private var currentTaxThreshold: TimeInterval = 4 * 3600 // Default 4 hours
    
    // MARK: - Notification Deduplication
    
    private var pendingNotificationIDs: Set<String> = []
    private let notificationDedupInterval: TimeInterval = 5.0 // 5 second dedup window
    private var lastNotificationTimes: [String: Date] = [:]
    private let notificationLock = NSLock()
    
    // MARK: - Constants
    
    private let kNotificationsEnabled = "sunnyz.notifications.enabled"
    private let kWarningNotificationsEnabled = "sunnyz.notifications.warningEnabled"
    private let kDailySummaryEnabled = "sunnyz.notifications.dailySummaryEnabled"
    private let kDailySummaryTime = "sunnyz.notifications.dailySummaryTime"
    
    private let kHasShown30MinWarning = "sunnyz.notifications.hasShown30Min"
    private let kHasShown5MinWarning = "sunnyz.notifications.hasShown5Min"
    private let kHasShownTaxApplied = "sunnyz.notifications.hasShownTaxApplied"
    private let kLastTaxStatus = "sunnyz.notifications.lastTaxStatus"

    /// Whether we can safely use UNUserNotificationCenter (requires .app bundle)
    private nonisolated static var canUseNotifications: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
    }

    private var canUseNotifications: Bool {
        Self.canUseNotifications
    }

    static let shared = NotificationManager()
    
    // MARK: - Notification Identifiers
    
    enum NotificationID {
        static let warning30Min = "sunnyz.warning.30min"
        static let warning5Min = "sunnyz.warning.5min"
        static let taxApplied = "sunnyz.tax.applied"
        static let dailySummary = "sunnyz.daily.summary"
        static let actionPayTax = "sunnyz.action.payTax"
        static let actionDismiss = "sunnyz.action.dismiss"
        static let actionViewStats = "sunnyz.action.viewStats"
    }
    
    // MARK: - Snarky Messages
    
    private let warning30MinMessages = [
        "🌤️ Tax season is approaching... You've got 30 minutes before your cave-dwelling costs you.",
        "⏰ 30 minutes until sunlight tax. The outdoors is calling (and so is your wallet).",
        "🦇 Your inner bat is thriving, but your bank account is nervous. 30 min warning!",
        "📉 Vitamin D levels critical. Tax countdown: 30 minutes.",
        "🏠 The cave is cozy, but freedom costs $0.99 in 30 minutes."
    ]
    
    private let warning5MinMessages = [
        "🚨 FINAL WARNING: 5 minutes until tax! Run for the sunlight!",
        "⏰ This is not a drill. 5 minutes until your screen dims and your wallet cries.",
        "💸 Last chance! Go outside now or prepare to pay the cave troll tax.",
        "🧛 Even vampires are telling you to get some sun. 5 minutes left!",
        "🔴 T-MINUS 5 MINUTES: Touch grass or pay the price!"
    ]
    
    private let taxAppliedMessages = [
        "💸 SUNLIGHT TAX APPLIED! Your screen brightness has been reduced to 50%.",
        "🧌 Cave troll status confirmed. Pay $0.99 to restore full brightness.",
        "📉 Your screen is now 50% darker, just like your soul. Pay tax to brighten up!",
        "🏚️ Welcome to the darkness. Premium cave dwelling costs extra.",
        "💳 Tax collected! Your wallet feels lighter, and so does your screen."
    ]
    
    // MARK: - Initialization
    
    private override init() {
        // Load settings from UserDefaults with defaults
        let defaults = UserDefaults.standard
        self.notificationsEnabled = defaults.object(forKey: kNotificationsEnabled) as? Bool ?? true
        self.warningNotificationsEnabled = defaults.object(forKey: kWarningNotificationsEnabled) as? Bool ?? true
        self.dailySummaryEnabled = defaults.object(forKey: kDailySummaryEnabled) as? Bool ?? true
        
        // Default summary time is 9 PM
        if let savedTime = defaults.object(forKey: kDailySummaryTime) as? Date {
            self.dailySummaryTime = savedTime
        } else {
            var components = DateComponents()
            components.hour = 21
            components.minute = 0
            self.dailySummaryTime = Calendar.current.date(from: components) ?? Date()
        }
        
        // Load notification state
        self.hasShown30MinWarning = defaults.bool(forKey: kHasShown30MinWarning)
        self.hasShown5MinWarning = defaults.bool(forKey: kHasShown5MinWarning)
        self.hasShownTaxApplied = defaults.bool(forKey: kHasShownTaxApplied)
        
        super.init()

        // Set up notification delegate
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories
        registerNotificationCategories()

        // Check authorization status
        checkAuthorizationStatus()

        // Schedule daily summary if enabled
        if dailySummaryEnabled {
            scheduleDailySummary()
        }
        
        // Listen for tax threshold changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTaxThresholdChange),
            name: .taxThresholdChanged,
            object: nil
        )
    }
    
    @objc private func handleTaxThresholdChange() {
        // Reset warning states when threshold changes
        resetNotificationState()
        // Update internal threshold reference
        currentTaxThreshold = SettingsManager.shared.taxThresholdInterval
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            Task { @MainActor in
                self.isAuthorized = granted
                if granted {
                    print("[SunnyZ] Notification authorization granted")
                } else if let error = error {
                    print("[SunnyZ] Notification authorization error: \(error)")
                } else {
                    print("[SunnyZ] Notification authorization denied")
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let isAuthorized = settings.authorizationStatus == .authorized
            Task { @MainActor in
                self.isAuthorized = isAuthorized
            }
        }
    }
    
    // MARK: - Notification Categories
    
    private func registerNotificationCategories() {
        guard canUseNotifications else { return }

        // Tax applied category with actions
        let payTaxAction = UNNotificationAction(
            identifier: NotificationID.actionPayTax,
            title: "Pay Tax",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: NotificationID.actionDismiss,
            title: "Dismiss",
            options: .destructive
        )
        
        let taxCategory = UNNotificationCategory(
            identifier: NotificationID.taxApplied,
            actions: [payTaxAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Daily summary category
        let viewStatsAction = UNNotificationAction(
            identifier: NotificationID.actionViewStats,
            title: "View Stats",
            options: .foreground
        )
        
        let summaryCategory = UNNotificationCategory(
            identifier: NotificationID.dailySummary,
            actions: [viewStatsAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([taxCategory, summaryCategory])
    }
    
    // MARK: - Warning Notifications
    
    func checkAndSendWarnings(timeInDarkness: TimeInterval, taxThreshold: TimeInterval, taxStatus: SunlightTaxManager.TaxStatus) {
        guard notificationsEnabled && warningNotificationsEnabled else { return }
        guard isAuthorized else { return }
        
        // Update current threshold reference
        currentTaxThreshold = taxThreshold
        
        let timeUntilTax = max(0, taxThreshold - timeInDarkness)
        
        // 30-minute warning (or proportional if threshold is shorter)
        let warning30Time = min(30 * 60, taxThreshold * 0.125) // 12.5% of threshold time
        let warning5Time = min(5 * 60, taxThreshold * 0.02)   // 2% of threshold time
        
        // 30-minute warning
        if timeUntilTax <= warning30Time && timeUntilTax > warning5Time && !hasShown30MinWarning {
            // Check for deduplication
            guard canSendNotification(id: NotificationID.warning30Min) else { return }
            
            send30MinuteWarning(timeUntilTax: timeUntilTax)
            hasShown30MinWarning = true
            saveNotificationState()
            recordNotificationSent(id: NotificationID.warning30Min)
        }
        
        // 5-minute warning
        if timeUntilTax <= warning5Time && timeUntilTax > 0 && !hasShown5MinWarning {
            // Check for deduplication
            guard canSendNotification(id: NotificationID.warning5Min) else { return }
            
            send5MinuteWarning(timeUntilTax: timeUntilTax)
            hasShown5MinWarning = true
            saveNotificationState()
            recordNotificationSent(id: NotificationID.warning5Min)
        }
        
        // Tax applied notification
        if taxStatus == .taxed && lastTaxStatus != .taxed && !hasShownTaxApplied {
            // Check for deduplication
            guard canSendNotification(id: NotificationID.taxApplied) else { return }
            
            sendTaxAppliedNotification()
            hasShownTaxApplied = true
            saveNotificationState()
            recordNotificationSent(id: NotificationID.taxApplied)
        }
        
        lastTaxStatus = taxStatus
        UserDefaults.standard.set(taxStatus == .taxed ? 1 : 0, forKey: kLastTaxStatus)
    }
    
    // MARK: - Notification Deduplication
    
    /// Checks if a notification can be sent (not a duplicate within the dedup window)
    private func canSendNotification(id: String) -> Bool {
        notificationLock.lock()
        defer { notificationLock.unlock() }
        
        // Check if there's a pending notification with this ID
        if pendingNotificationIDs.contains(id) {
            print("[SunnyZ] Notification dedup: \(id) already pending")
            return false
        }
        
        // Check if we've sent this notification recently
        if let lastTime = lastNotificationTimes[id] {
            let timeSinceLast = Date().timeIntervalSince(lastTime)
            if timeSinceLast < notificationDedupInterval {
                print("[SunnyZ] Notification dedup: \(id) sent \(Int(timeSinceLast))s ago")
                return false
            }
        }
        
        return true
    }
    
    /// Records that a notification has been sent
    private func recordNotificationSent(id: String) {
        notificationLock.lock()
        defer { notificationLock.unlock() }
        
        pendingNotificationIDs.insert(id)
        lastNotificationTimes[id] = Date()
        
        // Clean up pending ID after dedup interval
        DispatchQueue.main.asyncAfter(deadline: .now() + notificationDedupInterval) { [weak self] in
            self?.notificationLock.lock()
            self?.pendingNotificationIDs.remove(id)
            self?.notificationLock.unlock()
        }
    }
    
    private func send30MinuteWarning(timeUntilTax: TimeInterval) {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "⏰ Sunlight Tax Warning"
        content.body = warning30MinMessages.randomElement() ?? warning30MinMessages[0]
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: NotificationID.warning30Min,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send 30-min warning: \(error)")
            } else {
                print("[SunnyZ] Sent 30-minute warning notification")
            }
        }
    }
    
    private func send5MinuteWarning(timeUntilTax: TimeInterval) {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "🚨 FINAL WARNING"
        content.body = warning5MinMessages.randomElement() ?? warning5MinMessages[0]
        content.sound = .defaultCritical
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: NotificationID.warning5Min,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send 5-min warning: \(error)")
            } else {
                print("[SunnyZ] Sent 5-minute warning notification")
            }
        }
    }
    
    // MARK: - Tax Applied Notification
    
    private func sendTaxAppliedNotification() {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "💸 Sunlight Tax Applied!"
        content.body = taxAppliedMessages.randomElement() ?? taxAppliedMessages[0]
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = NotificationID.taxApplied
        
        let request = UNNotificationRequest(
            identifier: NotificationID.taxApplied,
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send tax applied notification: \(error)")
            } else {
                print("[SunnyZ] Sent tax applied notification")
            }
        }
    }
    
    // MARK: - Daily Summary
    
    func scheduleDailySummary() {
        guard canUseNotifications else { return }
        guard notificationsEnabled && dailySummaryEnabled && isAuthorized else { return }
        
        // Cancel existing summary
        cancelDailySummary()
        
        // Calculate next occurrence
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        
        let summaryTimeComponents = calendar.dateComponents([.hour, .minute], from: dailySummaryTime)
        components.hour = summaryTimeComponents.hour
        components.minute = summaryTimeComponents.minute
        
        var triggerDate = calendar.date(from: components) ?? now
        
        // If time has passed today, schedule for tomorrow
        if triggerDate <= now {
            triggerDate = calendar.date(byAdding: .day, value: 1, to: triggerDate) ?? triggerDate
        }
        
        let timeInterval = triggerDate.timeIntervalSince(now)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        
        let content = createDailySummaryContent()
        
        let request = UNNotificationRequest(
            identifier: NotificationID.dailySummary,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to schedule daily summary: \(error)")
            } else {
                print("[SunnyZ] Scheduled daily summary for \(triggerDate)")
            }
        }
    }
    
    private func createDailySummaryContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "🌅 Daily Cave Report"
        content.categoryIdentifier = NotificationID.dailySummary
        
        // Get stats from shared instance
        let taxManager = SunlightTaxManager.shared
        let timeInDarkness = taxManager.formattedTimeInDarkness
        let totalTax = taxManager.formattedTotalTax
        let status = taxManager.taxStatus.icon
        
        content.body = "\(status) Today: \(timeInDarkness) in darkness | Total tax paid: \(totalTax)"
        content.sound = .default
        content.badge = 1
        
        return content
    }
    
    func cancelDailySummary() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [NotificationID.dailySummary])
    }
    
    func rescheduleDailySummary() {
        if dailySummaryEnabled {
            scheduleDailySummary()
        }
    }
    
    // MARK: - State Management
    
    func resetNotificationState() {
        guard canUseNotifications else { return }
        // Called when user goes outside (sunlight detected) or threshold changes
        hasShown30MinWarning = false
        hasShown5MinWarning = false
        hasShownTaxApplied = false
        saveNotificationState()
        
        // Remove delivered notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [
            NotificationID.warning30Min,
            NotificationID.warning5Min,
            NotificationID.taxApplied
        ])
        
        print("[SunnyZ] Reset notification state")
    }
    
    private func saveNotificationState() {
        let defaults = UserDefaults.standard
        defaults.set(hasShown30MinWarning, forKey: kHasShown30MinWarning)
        defaults.set(hasShown5MinWarning, forKey: kHasShown5MinWarning)
        defaults.set(hasShownTaxApplied, forKey: kHasShownTaxApplied)
    }
    
    func clearBadge() {
        guard canUseNotifications else { return }
        UNUserNotificationCenter.current().setBadgeCount(0)
    }
    
    // MARK: - Action Handling
    
    func handleNotificationAction(identifier: String) {
        switch identifier {
        case NotificationID.actionPayTax:
            print("[SunnyZ] User tapped Pay Tax from notification")
            NotificationCenter.default.post(name: .showPaywall, object: nil)
            
        case NotificationID.actionDismiss:
            print("[SunnyZ] User dismissed tax notification")
            clearBadge()
            
        case NotificationID.actionViewStats:
            print("[SunnyZ] User tapped View Stats from notification")
            NotificationCenter.default.post(name: .showMenu, object: nil)
            
        default:
            break
        }
    }
    
    // MARK: - Test Notifications
    
    /// Sends a test 30-minute warning style notification immediately (bypasses state checks)
    public func sendTestWarningNotification() {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test: Sunlight Tax Warning"
        content.body = warning30MinMessages.randomElement() ?? warning30MinMessages[0]
        content.sound = .default
        content.badge = 1
        
        let request = UNNotificationRequest(
            identifier: NotificationID.warning30Min + ".test",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send test warning notification: \(error)")
            } else {
                print("[SunnyZ] Sent test warning notification")
            }
        }
    }
    
    /// Sends a test tax applied style notification immediately (bypasses state checks)
    public func sendTestTaxAppliedNotification() {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test: Sunlight Tax Applied!"
        content.body = taxAppliedMessages.randomElement() ?? taxAppliedMessages[0]
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = NotificationID.taxApplied
        
        let request = UNNotificationRequest(
            identifier: NotificationID.taxApplied + ".test",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send test tax applied notification: \(error)")
            } else {
                print("[SunnyZ] Sent test tax applied notification")
            }
        }
    }
    
    /// Sends a test daily summary style notification immediately (bypasses state checks)
    public func sendTestDailySummary() {
        guard canUseNotifications else { return }
        let content = createDailySummaryContent()
        content.title = "🧪 Test: Daily Cave Report"
        
        let request = UNNotificationRequest(
            identifier: NotificationID.dailySummary + ".test",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send test daily summary: \(error)")
            } else {
                print("[SunnyZ] Sent test daily summary notification")
            }
        }
    }
    
    /// Sends a test snarky reminder notification immediately using SnarkManager
    public func sendTestSnarkyReminder() {
        guard canUseNotifications else { return }
        let content = UNMutableNotificationContent()
        content.title = "🧪 Test: Snarky Reminder"
        content.body = SnarkManager.shared.getSnarkyMessage()
        content.sound = .default
        content.badge = 1
        
        // Add snark level indicator from SnarkManager
        switch SnarkManager.shared.snarkLevel {
        case .mild:
            content.subtitle = "Gentle reminder"
        case .medium:
            content.subtitle = "You should probably listen..."
        case .savage:
            content.subtitle = "No holding back"
        }
        
        let request = UNNotificationRequest(
            identifier: "sunnyz.snark.test.\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SunnyZ] Failed to send test snarky reminder: \(error)")
            } else {
                print("[SunnyZ] Sent test snarky reminder notification")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        guard Self.canUseNotifications else {
            completionHandler([])
            return
        }
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard Self.canUseNotifications else {
            completionHandler()
            return
        }
        let actionIdentifier = response.actionIdentifier

        // Handle default "tap" action
        if actionIdentifier == UNNotificationDefaultActionIdentifier {
            let notificationId = response.notification.request.identifier
            // Use Task to hop back to MainActor for action handling
            Task { @MainActor in
                if notificationId == NotificationID.taxApplied {
                    handleNotificationAction(identifier: NotificationID.actionPayTax)
                } else if notificationId == NotificationID.dailySummary {
                    handleNotificationAction(identifier: NotificationID.actionViewStats)
                }
            }
        } else {
            // Use Task to hop back to MainActor for action handling
            Task { @MainActor in
                handleNotificationAction(identifier: actionIdentifier)
            }
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let showPaywall = Notification.Name("showPaywall")
    static let showMenu = Notification.Name("showMenu")
}
