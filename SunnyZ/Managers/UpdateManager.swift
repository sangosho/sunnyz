//
//  UpdateManager.swift
//  SunnyZ
//
//  Handles automatic app updates using Sparkle framework
//

import Foundation
import Sparkle

/// Manages app updates using Sparkle framework
@MainActor
final class UpdateManager: NSObject, ObservableObject {

    static let shared = UpdateManager()

    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false
    @Published var automaticallyChecksForUpdates = true
    @Published var automaticallyDownloadsUpdates = false

    private override init() {
        // Initialize Sparkle updater controller
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        super.init()

        // Configure update settings
        configureUpdates()
    }

    private func configureUpdates() {
        let updater = updaterController.updater

        // Enable automatic update checks (daily)
        updater.automaticallyChecksForUpdates = true

        // Check for updates on startup (with a small delay to not slow down launch)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            updater.checkForUpdatesInBackground()
        }

        // Get current settings
        canCheckForUpdates = true
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates

        // Observe settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateSettingsChanged),
            name: NSNotification.Name("SUUpdateSettingsChanged"),
            object: nil
        )
    }

    // MARK: - Public Methods

    /// Check for updates immediately (shows UI if update available)
    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    /// Toggle automatic update checks
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }

    /// Toggle automatic download of updates
    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        automaticallyDownloadsUpdates = enabled
    }

    // MARK: - Private Methods

    @objc private func updateSettingsChanged() {
        let updater = updaterController.updater
        automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateManager: SPUUpdaterDelegate {

    /// Returns the URL for the appcast feed
    func feedURLString(for updater: SPUUpdater) -> String? {
        // Appcast hosted on GitHub releases
        return "https://raw.githubusercontent.com/sangosho/sunnyz/main/appcast.xml"
    }
}
