//
//  MenuBarController.swift
//  SunnyZ
//
//  Menu bar controller for Sunlight Tax with lux sensor support
//

import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject, ObservableObject {

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var taxManager: SunlightTaxManager!
    private var cancellables = Set<AnyCancellable>()
    private var achievementManager = AchievementManager.shared

    // Easter egg tracking
    private var menuClickCount = 0
    private var menuClickTimer: Timer?
    private var konamiIndex = 0
    private let konamiCode: [NSEvent.SpecialKey] = [
        .upArrow, .upArrow, .downArrow, .downArrow,
        .leftArrow, .rightArrow, .leftArrow, .rightArrow,
        .keyB, .keyA
    ]

    override init() {
        super.init()
        setupMenuBar()
        setupEasterEggMonitor()
    }
    
    private func setupMenuBar() {
        taxManager = SunlightTaxManager()

        // Create status item
        statusItem = NSStatusBar.shared.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "sun.max.fill",
                accessibilityDescription: "SunnyZ"
            )
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuPopoverView(taxManager: taxManager)
        )
        
        // Subscribe to status changes
        taxManager.$taxStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.updateMenuIcon(status: status)
            }
            .store(in: &cancellables)
        
        // Subscribe to timeInDarkness for notification triggers
        taxManager.$timeInDarkness
            .receive(on: DispatchQueue.main)
            .sink { [weak self] timeInDarkness in
                self?.checkNotifications(timeInDarkness: timeInDarkness)
            }
            .store(in: &cancellables)
        
        // Subscribe to lux changes to reset notification state when going outside
        taxManager.$currentLux
            .receive(on: DispatchQueue.main)
            .sink { [weak self] lux in
                self?.handleLuxChange(lux: lux)
            }
            .store(in: &cancellables)

        // Subscribe to tax payments to track achievements
        taxManager.$totalTaxPaid
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.checkAchievements()
            }
            .store(in: &cancellables)

        // Listen for show achievements notification
        NotificationCenter.default.publisher(for: .showAchievements)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.showAchievements()
            }
            .store(in: &cancellables)
    }

    private func setupEasterEggMonitor() {
        // Monitor for Konami code via NSEvent
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        guard let specialKey = event.specialKey else { return }

        if konamiIndex < konamiCode.count && specialKey == konamiCode[konamiIndex] {
            konamiIndex += 1

            // Check if Konami code complete
            if konamiIndex == konamiCode.count {
                triggerKonamiEasterEgg()
                konamiIndex = 0
            }
        } else {
            konamiIndex = 0
        }
    }

    private func triggerKonamiEasterEgg() {
        let alert = NSAlert()
        alert.messageText = "🎮 Cheat Code Activated!"
        alert.informativeText = "You know the classics! But there are no cheats for sunlight. Go outside."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func trackMenuClick() {
        menuClickCount += 1

        // Reset timer
        menuClickTimer?.invalidate()
        menuClickTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.menuClickCount = 0
        }

        // Check for rapid clicks
        if menuClickCount >= 10 {
            triggerRapidClickEasterEgg()
            menuClickCount = 0
        }
    }

    private func triggerRapidClickEasterEgg() {
        let alert = NSAlert()
        alert.messageText = "Are you okay?"
        alert.informativeText = "You clicked the menu bar 10 times rapidly. Everything will be okay. Just... touch grass?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "I'm fine")
        alert.runModal()
    }

    private func checkAprilFoolsEasterEgg() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: Date())

        if components.month == 4 && components.day == 1 {
            // April 1st - special tax rate message
            let alert = NSAlert()
            alert.messageText = "🎉 April Fools!"
            alert.informativeText = "Today's special: 100% discount on the sunlight tax! (Not really, you still have to pay)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "😐")
            alert.runModal()
        }
    }

    private func checkAchievements() {
        let taxPaymentCount = UserDefaults.standard.integer(forKey: "sunlightTax.taxPaymentCount")

        achievementManager.checkAchievements(
            timeInDarkness: taxManager.timeInDarkness,
            totalTaxPaid: taxManager.totalTaxPaid,
            taxPaymentCount: taxPaymentCount,
            lastSunlightDate: taxManager.lastSunlightDate,
            isTaxed: taxManager.taxStatus == .taxed
        )
    }

    private func checkNotifications(timeInDarkness: TimeInterval) {
        NotificationManager.shared.checkAndSendWarnings(
            timeInDarkness: timeInDarkness,
            taxThreshold: taxManager.taxThreshold,
            taxStatus: taxManager.taxStatus
        )

        // Track night owl activity
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 {
            achievementManager.trackNightOwlActivity()
        }
    }
    
    private var lastLuxWasSunlight = false

    private func handleLuxChange(lux: Double) {
        let isSunlight = lux >= taxManager.sunlightThreshold

        // Reset notification state and trigger achievements when going from darkness to sunlight
        if isSunlight && !lastLuxWasSunlight {
            NotificationManager.shared.resetNotificationState()

            // Handle going outside for achievements
            achievementManager.handleWentOutside(timeInDarkness: taxManager.timeInDarkness)
            checkAchievements()

            // Check April Fools easter egg
            checkAprilFoolsEasterEgg()
        }

        lastLuxWasSunlight = isSunlight
    }
    
    private func updateMenuIcon(status: SunlightTaxManager.TaxStatus) {
        guard let button = statusItem.button else { return }
        
        button.image = NSImage(
            systemSymbolName: status.menuIcon,
            accessibilityDescription: "SunnyZ"
        )
        button.image?.size = NSSize(width: 18, height: 18)
        button.contentTintColor = status.color
    }
    
    @objc private func togglePopover() {
        trackMenuClick()

        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Clear badge when opening menu
                NotificationManager.shared.clearBadge()
            }
        }
    }
    
    func showPopover() {
        if let button = statusItem.button, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NotificationManager.shared.clearBadge()
        }
    }
    
    func showPaywall() {
        let paywallWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        paywallWindow.title = "Pay Sunlight Tax"
        paywallWindow.center()
        paywallWindow.contentView = NSHostingView(
            rootView: TaxPaywallView(taxManager: taxManager)
        )
        paywallWindow.makeKeyAndOrderFront(nil)
    }
    
    func showPremium() {
        let premiumWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        premiumWindow.title = "Premium Subscription"
        premiumWindow.center()
        premiumWindow.contentView = NSHostingView(
            rootView: PremiumSubscriptionView(taxManager: taxManager)
        )
        premiumWindow.makeKeyAndOrderFront(nil)
    }
    
    func showSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "SunnyZ Settings"
        settingsWindow.center()
        settingsWindow.contentView = NSHostingView(
            rootView: SettingsView(taxManager: taxManager)
        )
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    func showAchievements() {
        let achievementsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        achievementsWindow.title = "Achievements"
        achievementsWindow.center()
        achievementsWindow.contentView = NSHostingView(
            rootView: AchievementsView()
        )
        achievementsWindow.makeKeyAndOrderFront(nil)
    }
}
