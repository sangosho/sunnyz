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
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController!
    
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
}

// MARK: - Extension for LuxSensorManager shared access

extension LuxSensorManager {
    static let shared = LuxSensorManager()
}
