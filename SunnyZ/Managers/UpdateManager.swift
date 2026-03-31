//
//  UpdateManager.swift
//  SunnyZ
//
//  Handles automatic app updates using Sparkle framework
//

import Combine
import Foundation
import Sparkle

/// Manages app updates using Sparkle framework.
///
/// Follows the official Sparkle 2 programmatic SwiftUI setup pattern:
/// https://sparkle-project.org/documentation/programmatic-setup
///
/// Key design decisions based on official docs:
/// - `canCheckForUpdates` is driven by KVO on `SPUUpdater.canCheckForUpdates`,
///   not set manually — so the menu item reflects the true updater state.
/// - We do NOT call `checkForUpdatesInBackground` manually on startup; Sparkle
///   handles scheduling automatically (default: every 24 hours).
/// - The appcast URL is provided via `feedURLString(for:)` delegate method,
///   which overrides the `SUFeedURL` in Info.plist at runtime.
@MainActor
final class UpdateManager: NSObject, ObservableObject {

    static let shared = UpdateManager()

    // Stored as `var` (implicitly-unwrapped optional) so we can complete
    // `super.init()` before passing `self` as the delegate — required by
    // Swift's two-phase initialisation rule for NSObject subclasses.
    // Sparkle stores the delegate weakly, so UpdateManager.shared keeps it alive.
    private var updaterController: SPUStandardUpdaterController!

    /// Mirrors `SPUUpdater.canCheckForUpdates` via KVO for use in SwiftUI.
    @Published var canCheckForUpdates = false

    /// Mirrors `SPUUpdater.automaticallyChecksForUpdates` (backed by NSUserDefaults).
    @Published var automaticallyChecksForUpdates = true

    /// Mirrors `SPUUpdater.automaticallyDownloadsUpdates` (backed by NSUserDefaults).
    @Published var automaticallyDownloadsUpdates = false

    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()

        // Create the controller with `startingUpdater: false` so we finish
        // wiring up KVO before the first automatic check fires, then start it.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Drive `canCheckForUpdates` from Sparkle's KVO-compliant property
        // rather than hardcoding it to `true`.
        updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .assign(to: &$canCheckForUpdates)

        // Mirror the user-preference-backed properties once on startup.
        automaticallyChecksForUpdates = updaterController.updater.automaticallyChecksForUpdates
        automaticallyDownloadsUpdates = updaterController.updater.automaticallyDownloadsUpdates

        updaterController.startUpdater()
    }

    // MARK: - Public Methods

    /// Triggers a user-visible update check (shows progress/results UI).
    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }

    /// Persists the user's preference for automatic update checks.
    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecksForUpdates = enabled
    }

    /// Persists the user's preference for automatic update downloads.
    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController.updater.automaticallyDownloadsUpdates = enabled
        automaticallyDownloadsUpdates = enabled
    }
}

// MARK: - SPUUpdaterDelegate

extension UpdateManager: SPUUpdaterDelegate {

    /// Overrides the `SUFeedURL` Info.plist key at runtime.
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        "https://raw.githubusercontent.com/sangosho/sunnyz/main/appcast.xml"
    }
}
