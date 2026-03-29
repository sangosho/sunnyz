//
//  MenuBarController.swift
//  SunnyZ
//
//  Menu bar controller for Sunlight Tax
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
    
    override init() {
        super.init()
        setupMenuBar()
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
        popover.contentSize = NSSize(width: 320, height: 400)
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
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
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
}
