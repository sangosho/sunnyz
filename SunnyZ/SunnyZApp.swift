//
//  SunnyZApp.swift
//  SunnyZ
//
//  Menu bar app entry point
//

import SwiftUI

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
        
        // Setup menu bar
        menuBarController = MenuBarController()
        
        // Listen for premium window requests
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(showPremium),
            name: .showPremium,
            object: nil
        )
    }
    
    @objc private func showPremium() {
        menuBarController.showPremium()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep running in menu bar
    }
}
