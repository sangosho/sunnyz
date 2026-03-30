//
//  MenuBarController.swift
//  SunnyZ
//
//  Menu bar controller for Sunlight Tax with lux sensor support
//

import AppKit
import SwiftUI
@preconcurrency import Combine

@MainActor
final class MenuBarController: NSObject, ObservableObject, NSPopoverDelegate {

    static let shared = MenuBarController()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hostingController: NSHostingController<MenuPopoverView>?
    private var taxManager: SunlightTaxManager!
    private var cancellables = Set<AnyCancellable>()
    private var achievementManager = AchievementManager.shared

    // Weak window references — when a window is closed and deallocated,
    // the weak reference automatically nils out, preventing dangling pointers.
    private weak var settingsWindow: NSWindow?
    private weak var premiumWindow: NSWindow?
    private weak var paywallWindow: NSWindow?
    private weak var achievementsWindow: NSWindow?

    // Easter egg tracking
    private var menuClickCount = 0
    private var menuClickTimer: Timer?
    private var konamiIndex = 0
    private let konamiCode: [String] = [
        "Up", "Up", "Down", "Down",
        "Left", "Right", "Left", "Right",
        "b", "a"
    ]
    private var eventMonitor: Any?

    override init() {
        super.init()
        setupMenuBar()
        setupEasterEggMonitor()
    }
    
    @MainActor
    deinit {
        displayReconnectionTimer?.invalidate()
        menuClickTimer?.invalidate()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        cancellables.removeAll()
    }
    
    private var isPaused = false
    private var isUIUpdatesPaused = false
    private var accumulatedSleepTime: TimeInterval = 0
    private var displayReconnectionTimer: Timer?

    private func setupMenuBar() {
        taxManager = SunlightTaxManager.shared

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "sun.max.fill",
                accessibilityDescription: "SunnyZ - Sunlight Tax Tracker"
            )
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
            button.toolTip = "SunnyZ: Track your cave-dwelling time (⌘, for settings)"
        }

        // Setup display change monitoring
        setupDisplayChangeMonitoring()
        
        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 450)
        popover.behavior = .transient
        popover.delegate = self
        hostingController = NSHostingController(
            rootView: MenuPopoverView(taxManager: taxManager)
        )
        popover.contentViewController = hostingController
        
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

        // Subscribe to debug mode changes to update menu icon
        SettingsManager.shared.$debugModeEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateMenuIcon(status: self.taxManager.taxStatus)
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
        // Monitor for Konami code via NSEvent; store the token so we can remove it in deinit
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return event
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        var keyString: String?

        if let specialKey = event.specialKey {
            switch specialKey {
            case .upArrow: keyString = "Up"
            case .downArrow: keyString = "Down"
            case .leftArrow: keyString = "Left"
            case .rightArrow: keyString = "Right"
            default: break
            }
        } else {
            keyString = event.charactersIgnoringModifiers?.lowercased()
        }

        guard let key = keyString else { return }

        if konamiIndex < konamiCode.count && key == konamiCode[konamiIndex].lowercased() {
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
            Task { @MainActor in
                self?.menuClickCount = 0
            }
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
        
        let isDebugMode = SettingsManager.shared.debugModeEnabled
        
        button.image = NSImage(
            systemSymbolName: status.menuIcon,
            accessibilityDescription: isDebugMode ? "SunnyZ (DEBUG)" : "SunnyZ"
        )
        button.image?.size = NSSize(width: 18, height: 18)
        
        let nsColor: NSColor
        switch status {
        case .exempt: nsColor = .systemGreen
        case .warning: nsColor = .systemOrange
        case .taxed: nsColor = .systemRed
        case .premium: nsColor = .systemPurple
        }
        button.contentTintColor = nsColor
        
        // Update tooltip with debug indicator if enabled
        if isDebugMode {
            button.toolTip = "🔧 SunnyZ: Track your cave-dwelling time (⌘, for settings) [DEBUG MODE]"
            button.title = "🔧"
        } else {
            button.toolTip = "SunnyZ: Track your cave-dwelling time (⌘, for settings)"
            button.title = ""
        }
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
    
    func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }
    
    func showPopover() {
        if let button = statusItem.button, !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NotificationManager.shared.clearBadge()
        }
    }
    
    func showPaywall() {
        if let existingWindow = paywallWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Pay Sunlight Tax"
        window.center()
        window.contentView = NSHostingView(
            rootView: TaxPaywallView(taxManager: taxManager)
        )
        window.delegate = self
        paywallWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    func showPremium() {
        if let existingWindow = premiumWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Premium Subscription"
        window.center()
        window.contentView = NSHostingView(
            rootView: PremiumSubscriptionView(taxManager: taxManager)
        )
        window.delegate = self
        premiumWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
    
    func showSettings() {
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "SunnyZ Settings"
        window.center()
        window.contentView = NSHostingView(
            rootView: SettingsView(taxManager: taxManager)
        )
        window.delegate = self
        settingsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func showAchievements() {
        if let existingWindow = achievementsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 580),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Achievements"
        window.center()
        window.contentView = NSHostingView(
            rootView: AchievementsView()
        )
        window.delegate = self
        achievementsWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Sleep/Wake Handling

    func pauseMonitoring() {
        isPaused = true
        print("[SunnyZ] Monitoring paused for sleep")
    }

    func resumeMonitoring(sleepDuration: TimeInterval) {
        isPaused = false
        accumulatedSleepTime = sleepDuration
        print("[SunnyZ] Monitoring resumed after sleep (duration: \(Int(sleepDuration/60)) min)")

        // Update tax manager to account for sleep time
        // We subtract sleep time from darkness calculation since user couldn't get sunlight
        taxManager.adjustForSleepDuration(sleepDuration)
    }

    func pauseUIUpdates() {
        isUIUpdatesPaused = true
    }

    func resumeUIUpdates() {
        isUIUpdatesPaused = false
        // Force an immediate update
        updateMenuIcon(status: taxManager.taxStatus)
    }

    // MARK: - Display Change Handling

    private func setupDisplayChangeMonitoring() {
        // Monitor for display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDisplayConfigurationChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleDisplayConfigurationChange() {
        print("[SunnyZ] Display configuration changed")

        // Invalidate and recreate display service
        displayReconnectionTimer?.invalidate()
        displayReconnectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.taxManager.refreshDisplayConnection()
            }
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        // Intentionally left empty: hostingController is kept alive so the
        // popover has a valid contentViewController on next open.
    }
}

// MARK: - NSWindowDelegate

extension MenuBarController: NSWindowDelegate {
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Window references are weak, so they nil automatically when the
        // window deallocates. No manual cleanup needed.
        return true
    }
}
