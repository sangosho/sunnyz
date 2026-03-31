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

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    UpdateManager.shared.checkForUpdates()
                }
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

 @MainActor
 class AppDelegate: NSObject, NSApplicationDelegate {
    private var sleepStartTime: Date?
    private var notificationObservers: [NSObjectProtocol] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize settings manager early
        _ = SettingsManager.shared
        
        // Setup notification manager
        setupNotifications()
        
        // Setup menu bar (triggers MenuBarController.shared lazy initialization)
        _ = MenuBarController.shared

        // Initialize update manager
        _ = UpdateManager.shared
        
        // Use block-based observers that access the singleton directly.
        // No reference to `self` is captured, so AppDelegate lifecycle
        // changes from @NSApplicationDelegateAdaptor can't cause dangling pointers.
        let nc = NotificationCenter.default
        
        notificationObservers.append(
            nc.addObserver(forName: .showPremium, object: nil, queue: .main) { _ in
                Task { @MainActor in MenuBarController.shared.showPremium() }
            }
        )
        
        notificationObservers.append(
            nc.addObserver(forName: .showPaywall, object: nil, queue: .main) { _ in
                Task { @MainActor in MenuBarController.shared.showPaywall() }
            }
        )
        
        notificationObservers.append(
            nc.addObserver(forName: .showMenu, object: nil, queue: .main) { _ in
                Task { @MainActor in MenuBarController.shared.showPopover() }
            }
        )
        
        notificationObservers.append(
            nc.addObserver(forName: .showSettings, object: nil, queue: .main) { _ in
                Task { @MainActor in MenuBarController.shared.showSettings() }
            }
        )
        
        // Setup sleep/wake notifications
        setupSleepWakeNotifications()
        
        // Setup system time change notification
        setupTimeChangeNotification()
        
        print("[SunnyZ] App launched successfully")
        print("[SunnyZ] Tax threshold: \(SettingsManager.shared.formattedTaxThreshold)")
        print("[SunnyZ] Environment classifier ready (calibrated: \(EnvironmentClassifier.shared.isCalibrated))")
    }
    
    private func setupNotifications() {
        // UNUserNotificationCenter requires a proper .app bundle;
        // guard against crashes when running via `swift run` (SPM executable)
        guard Bundle.main.bundlePath.hasSuffix(".app") else {
            print("[SunnyZ] Skipping notification setup — not running from an .app bundle")
            return
        }

        // Set the notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        
        // Request authorization on first launch
        let hasRequestedNotifications = UserDefaults.standard.bool(forKey: "sunnyz.hasRequestedNotifications")
        if !hasRequestedNotifications {
            NotificationManager.shared.requestAuthorization()
            UserDefaults.standard.set(true, forKey: "sunnyz.hasRequestedNotifications")
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Remove block-based notification observers
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
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
        MenuBarController.shared.pauseMonitoring()
    }
    
    @objc private func systemDidWake() {
        print("[SunnyZ] System woke from sleep")
        if let sleepStart = sleepStartTime {
            let sleepDuration = Date().timeIntervalSince(sleepStart)
            print("[SunnyZ] System slept for \(Int(sleepDuration/60)) minutes")
            // Don't count sleep time toward darkness - user couldn't have been in sunlight
            // Resume monitoring
            MenuBarController.shared.resumeMonitoring(sleepDuration: sleepDuration)
        }
        sleepStartTime = nil
    }
    
    @objc private func screensDidSleep() {
        print("[SunnyZ] Screens going to sleep")
        // Pause UI updates but keep tracking
        MenuBarController.shared.pauseUIUpdates()
    }
    
    @objc private func screensDidWake() {
        print("[SunnyZ] Screens woke up")
        MenuBarController.shared.resumeUIUpdates()
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

// LuxSensorManager.shared is now defined in its LuxSensorManager.swift

// MARK: - Notification Names

extension Notification.Name {
    static let systemTimeChanged = Notification.Name("sunnyz.systemTimeChanged")
}
