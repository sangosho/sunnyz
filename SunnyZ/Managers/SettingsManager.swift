//
//  SettingsManager.swift
//  SunnyZ
//
//  Centralized settings persistence with UserDefaults
//

import Foundation
import Combine
import ServiceManagement

/// Manages all user settings with reactive updates
@MainActor
final class SettingsManager: ObservableObject {
    
    // MARK: - Shared Instance
    static let shared = SettingsManager()
    
    // MARK: - Published Settings
    
    // MARK: Notifications
    @Published var notificationsEnabled: Bool {
        didSet { save(.notificationsEnabled, value: notificationsEnabled) }
    }
    
    @Published var warningNotificationsEnabled: Bool {
        didSet { save(.warningNotificationsEnabled, value: warningNotificationsEnabled) }
    }
    
    @Published var dailySummaryEnabled: Bool {
        didSet { 
            save(.dailySummaryEnabled, value: dailySummaryEnabled)
            if dailySummaryEnabled {
                NotificationManager.shared.scheduleDailySummary()
            } else {
                NotificationManager.shared.cancelDailySummary()
            }
        }
    }
    
    @Published var dailySummaryTime: Date {
        didSet { 
            save(.dailySummaryTime, value: dailySummaryTime)
            if dailySummaryEnabled {
                NotificationManager.shared.scheduleDailySummary()
            }
        }
    }
    
    // MARK: Tax Settings
    @Published var taxThresholdHours: TaxThreshold {
        didSet { 
            save(.taxThresholdHours, rawValue: taxThresholdHours.rawValue)
            // Notify that threshold changed
            NotificationCenter.default.post(name: .taxThresholdChanged, object: nil)
        }
    }
    
    @Published var showCountdownInMenuBar: Bool {
        didSet { save(.showCountdownInMenuBar, value: showCountdownInMenuBar) }
    }
    
    // MARK: Lux Sensor Settings
    @Published var luxCalibrationOffset: Double {
        didSet { save(.luxCalibrationOffset, value: luxCalibrationOffset) }
    }
    
    @Published var sunlightLuxThreshold: Double {
        didSet { save(.sunlightLuxThreshold, value: sunlightLuxThreshold) }
    }
    
    @Published var darknessLuxThreshold: Double {
        didSet { save(.darknessLuxThreshold, value: darknessLuxThreshold) }
    }
    
    // MARK: General Settings
    @Published var launchAtLogin: Bool {
        didSet {
            save(.launchAtLogin, value: launchAtLogin)
            updateLaunchAtLogin()
        }
    }
    
    // MARK: - Enums
    
    enum TaxThreshold: Int, CaseIterable, Identifiable {
        case twoHours = 2
        case fourHours = 4
        case eightHours = 8
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .twoHours: return "2 hours"
            case .fourHours: return "4 hours"
            case .eightHours: return "8 hours"
            }
        }
        
        var timeInterval: TimeInterval {
            return TimeInterval(rawValue * 3600)
        }
        
        var warningTimeInterval: TimeInterval {
            // Warning triggers 30 minutes before tax
            return timeInterval - (30 * 60)
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private enum Key: String {
        case notificationsEnabled = "sunnyz.settings.notifications.enabled"
        case warningNotificationsEnabled = "sunnyz.settings.notifications.warningEnabled"
        case dailySummaryEnabled = "sunnyz.settings.notifications.dailySummaryEnabled"
        case dailySummaryTime = "sunnyz.settings.notifications.dailySummaryTime"
        case taxThresholdHours = "sunnyz.settings.tax.thresholdHours"
        case showCountdownInMenuBar = "sunnyz.settings.tax.showCountdown"
        case luxCalibrationOffset = "sunnyz.settings.lux.calibrationOffset"
        case sunlightLuxThreshold = "sunnyz.settings.lux.sunlightThreshold"
        case darknessLuxThreshold = "sunnyz.settings.lux.darknessThreshold"
        case launchAtLogin = "sunnyz.settings.general.launchAtLogin"
    }
    
    // MARK: - Stats Keys (for reset functionality)
    
    private let statsKeys = [
        "sunlightTax.totalPaid",
        "sunlightTax.lastSunlight",
        "sunlightTax.hasPremium"
    ]
    
    // MARK: - Initialization
    
    private init() {
        let defaults = UserDefaults.standard
        
        // Load notification settings
        self.notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled.rawValue) as? Bool ?? true
        self.warningNotificationsEnabled = defaults.object(forKey: Key.warningNotificationsEnabled.rawValue) as? Bool ?? true
        self.dailySummaryEnabled = defaults.object(forKey: Key.dailySummaryEnabled.rawValue) as? Bool ?? true
        
        // Default summary time is 9 PM
        if let savedTime = defaults.object(forKey: Key.dailySummaryTime.rawValue) as? Date {
            self.dailySummaryTime = savedTime
        } else {
            var components = DateComponents()
            components.hour = 21
            components.minute = 0
            self.dailySummaryTime = Calendar.current.date(from: components) ?? Date()
        }
        
        // Load tax settings
        if let thresholdRaw = defaults.object(forKey: Key.taxThresholdHours.rawValue) as? Int,
           let threshold = TaxThreshold(rawValue: thresholdRaw) {
            self.taxThresholdHours = threshold
        } else {
            self.taxThresholdHours = .fourHours
        }
        
        self.showCountdownInMenuBar = defaults.object(forKey: Key.showCountdownInMenuBar.rawValue) as? Bool ?? true
        
        // Load lux settings
        self.luxCalibrationOffset = defaults.object(forKey: Key.luxCalibrationOffset.rawValue) as? Double ?? 0.0
        self.sunlightLuxThreshold = defaults.object(forKey: Key.sunlightLuxThreshold.rawValue) as? Double ?? 100.0
        self.darknessLuxThreshold = defaults.object(forKey: Key.darknessLuxThreshold.rawValue) as? Double ?? 50.0
        
        // Load general settings
        self.launchAtLogin = defaults.object(forKey: Key.launchAtLogin.rawValue) as? Bool ?? false
        
        // Sync launch at login state with system
        updateLaunchAtLogin()
    }
    
    // MARK: - Persistence Helpers
    
    private func save(_ key: Key, value: Bool) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    
    private func save(_ key: Key, value: Double) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    
    private func save(_ key: Key, value: Date) {
        UserDefaults.standard.set(value, forKey: key.rawValue)
    }
    
    private func save(_ key: Key, rawValue: Int) {
        UserDefaults.standard.set(rawValue, forKey: key.rawValue)
    }
    
    // MARK: - Launch at Login
    
    private func updateLaunchAtLogin() {
        // Note: SMAppService is available on macOS 13+
        // For older versions, we'd need to use SMLoginItemSetEnabled
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            do {
                let service = SMAppService.mainApp
                if launchAtLogin {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                print("[SunnyZ] Failed to update launch at login: \(error)")
            }
        }
        #endif
    }
    
    // MARK: - Reset Stats
    
    func resetAllStats() {
        // Reset all stats keys
        for key in statsKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Reset notification state
        NotificationManager.shared.resetNotificationState()
        
        // Post notification that stats were reset
        NotificationCenter.default.post(name: .statsReset, object: nil)
    }
    
    // MARK: - Lux Calibration
    
    func calibrateLux(currentReading: Double, actualLux: Double = 100.0) {
        let offset = actualLux - currentReading
        luxCalibrationOffset = offset
    }
    
    func applyCalibration(to lux: Double) -> Double {
        return lux + luxCalibrationOffset
    }
    
    // MARK: - Computed Properties
    
    var taxThresholdInterval: TimeInterval {
        taxThresholdHours.timeInterval
    }
    
    var warningThresholdInterval: TimeInterval {
        taxThresholdHours.warningTimeInterval
    }
    
    var formattedTaxThreshold: String {
        taxThresholdHours.displayName
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let taxThresholdChanged = Notification.Name("sunnyz.taxThresholdChanged")
    static let statsReset = Notification.Name("sunnyz.statsReset")
}
