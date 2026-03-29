//
//  SunnyZApp.swift
//  SunnyZ
//
//  Main app entry point
//

import SwiftUI

@main
struct SunnyZApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Configure appearance
        UINavigationBar.appearance().tintColor = .systemOrange
        
        return true
    }
}
