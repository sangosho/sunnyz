//
//  SunnyZApp.swift
//  SunnyZ
//
//  Main app entry point (macOS)
//

import SwiftUI

@main
struct SunnyZApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 700)
        }
        .windowStyle(.automatic)
        .commands {
            CommandMenu("SunnyZ") {
                Button("Check Sunlight Status") {
                    // Trigger status check
                }
                .keyboardShortcut("r", modifiers: .command)
                
                Divider()
                
                Button("Pay Tax") {
                    // Show paywall
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure appearance
        NSApp.appearance = NSAppearance(named: .aqua)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
