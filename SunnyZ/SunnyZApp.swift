//
//  SunnyZApp.swift
//  SunnyZ
//
//  Menu bar app entry point with enhanced lux detection
//

import SwiftUI
import UserNotifications

@main
struct SunnyZApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // No main window - menu bar only
        Settings {
            EmptyView()
        }
        .commands {
            // Add keyboard shortcuts
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandGroup(replacing: .appTermination) {
                Button("Quit SunnyZ") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController!
    private var sleepStartTime: Date?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize settings manager early
        _ = SettingsManager.shared
        
        // Setup notification manager
        setupNotifications()
        
        // Setup menu bar
        menuBarController = MenuBarController()
        
        // Listen for premium window requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPremium),
            name: .showPremium,
            object: nil
        )
        
        // Listen for paywall requests from notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPaywall),
            name: .showPaywall,
            object: nil
        )
        
        // Listen for menu show requests from notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showMenu),
            name: .showMenu,
            object: nil
        )
        
        // Listen for settings window requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showSettings),
            name: .showSettings,
            object: nil
        )
        
        // Setup sleep/wake notifications
        setupSleepWakeNotifications()
        
        // Setup system time change notification
        setupTimeChangeNotification()
        
        print("[SunnyZ] App launched successfully")
        print("[SunnyZ] Tax threshold: \(SettingsManager.shared.formattedTaxThreshold)")
        print("[SunnyZ] ALS Sensor available: \(LuxSensorManager.shared.hasALSSensor)")
    }
    
    private func setupNotifications() {
        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // Request authorization on first launch
        let hasRequestedNotifications = UserDefaults.standard.bool(forKey: "sunnyz.hasRequestedNotifications")
        if !hasRequestedNotifications {
            NotificationManager.shared.requestAuthorization()
            UserDefaults.standard.set(true, forKey: "sunnyz.hasRequestedNotifications")
        }
    }
    
    @objc private func showPremium() {
        menuBarController.showPremium()
    }
    
    @objc private func showPaywall() {
        menuBarController.showPaywall()
    }
    
    @objc private func showMenu() {
        menuBarController.showPopover()
    }
    
    @objc private func showSettings() {
        menuBarController.showSettings()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        print("[SunnyZ] App terminating")
    }
    
    // MARK: - Sleep/Wake Handling
    
    private func setupSleepWakeNotifications() {
        // Register for sleep notification
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        // Register for wake notification
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        // Register for screens sleep/wake
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensDidSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(screensDidWake),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        
        print("[SunnyZ] Sleep/wake notifications registered")
    }
    
    @objc private func systemWillSleep() {
        print("[SunnyZ] System going to sleep")
        sleepStartTime = Date()
        // Pause monitoring during sleep
        menuBarController?.pauseMonitoring()
    }
    
    @objc private func systemDidWake() {
        print("[SunnyZ] System woke from sleep")
        if let sleepStart = sleepStartTime {
            let sleepDuration = Date().timeIntervalSince(sleepStart)
            print("[SunnyZ] System slept for \(Int(sleepDuration/60)) minutes")
            // Don't count sleep time toward darkness - user couldn't have been in sunlight
            // Resume monitoring
            menuBarController?.resumeMonitoring(sleepDuration: sleepDuration)
        }
        sleepStartTime = nil
    }
    
    @objc private func screensDidSleep() {
        print("[SunnyZ] Screens going to sleep")
        // Pause UI updates but keep tracking
        menuBarController?.pauseUIUpdates()
    }
    
    @objc private func screensDidWake() {
        print("[SunnyZ] Screens woke up")
        menuBarController?.resumeUIUpdates()
    }
    
    // MARK: - System Time Change Handling
    
    private func setupTimeChangeNotification() {
        // Register for significant time change notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(systemTimeDidChange),
            name: .NSSystemClockDidChange,
            object: nil
        )
        
        // Register for timezone change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(timezoneDidChange),
            name: .NSSystemTimeZoneDidChange,
            object: nil
        )
    }
    
    @objc private func systemTimeDidChange() {
        print("[SunnyZ] System time changed - revalidating timers")
        // Revalidate and reschedule notifications
        NotificationManager.shared.rescheduleDailySummary()
        // Notify tax manager to revalidate state
        NotificationCenter.default.post(name: .systemTimeChanged, object: nil)
    }
    
    @objc private func timezoneDidChange() {
        print("[SunnyZ] Timezone changed - rescheduling notifications")
        NotificationManager.shared.rescheduleDailySummary()
    }
}

// MARK: - Extension for LuxSensorManager shared access

extension LuxSensorManager {
    static let shared = LuxSensorManager()
}

// MARK: - Notification Names

extension Notification.Name {
    static let systemTimeChanged = Notification.Name("sunnyz.systemTimeChanged")
}
