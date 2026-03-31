//
//  BrightnessController.swift
//  SunnyZ
//
//  Display brightness control via DisplayServices private framework.
//  Uses dlopen/dlsym for dynamic loading — no bridging header needed.
//
//  On Apple Silicon (M1+), IODisplayConnect does not exist in IORegistry.
//  DisplayServices is the only working brightness API.
//

import Foundation
import CoreGraphics

// MARK: - Function pointer types

private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

// MARK: - BrightnessController

/// Provides get/set brightness for the built-in display.
/// Loads DisplayServices.framework lazily at first use.
///
/// Marked `@MainActor` because all callers live on the main actor
/// (SunlightTaxManager) and the static mutable state needs a
/// synchronization domain.
@MainActor
final class BrightnessController: Sendable {

    static let shared = BrightnessController()

    // MARK: - State (loaded once, guarded by MainActor)

    private var getBrightnessFn: GetBrightnessFn?
    private var setBrightnessFn: SetBrightnessFn?
    private var loaded = false
    private(set) var available = false

    private init() {}

    // MARK: - Display Discovery

    /// Returns the main built-in display ID.
    private var builtInDisplayID: CGDirectDisplayID? {
        let maxDisplays: UInt32 = 16
        var onlineDisplays = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        guard CGGetOnlineDisplayList(maxDisplays, &onlineDisplays, &displayCount) == .success else {
            return nil
        }

        for i in 0..<displayCount {
            let id = onlineDisplays[Int(i)]
            if CGDisplayIsBuiltin(id) != 0 {
                return id
            }
        }
        return nil
    }

    // MARK: - Loading

    /// Whether DisplayServices was successfully loaded.
    var isAvailable: Bool {
        ensureLoaded()
        return available
    }

    private func ensureLoaded() {
        guard !loaded else { return }
        loaded = true

        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_LAZY
        ) else {
            print("[SunnyZ] BrightnessController: DisplayServices.framework not available: \(String(cString: dlerror()))")
            return
        }

        getBrightnessFn = unsafeBitCast(
            dlsym(handle, "DisplayServicesGetBrightness"),
            to: GetBrightnessFn.self
        )
        setBrightnessFn = unsafeBitCast(
            dlsym(handle, "DisplayServicesSetBrightness"),
            to: SetBrightnessFn.self
        )

        available = (getBrightnessFn != nil && setBrightnessFn != nil)

        if !available {
            print("[SunnyZ] BrightnessController: DisplayServices symbols not found")
        } else {
            print("[SunnyZ] BrightnessController: DisplayServices loaded successfully")
        }
    }

    // MARK: - Get/Set

    /// Reads the current brightness of the built-in display (0.0–1.0).
    /// Returns nil if the framework is not available.
    func getBrightness() -> Double? {
        ensureLoaded()
        guard let getFn = getBrightnessFn, let displayID = builtInDisplayID else { return nil }

        var brightness: Float = 0
        let result = getFn(displayID, &brightness)
        return result == 0 ? Double(brightness) : nil
    }

    /// Sets the brightness of the built-in display (0.0–1.0).
    /// Returns true on success.
    @discardableResult
    func setBrightness(_ value: Double) -> Bool {
        ensureLoaded()
        guard let setFn = setBrightnessFn, let displayID = builtInDisplayID else { return false }

        let clamped = Float(max(0, min(1, value)))
        let result = setFn(displayID, clamped)
        if result != 0 {
            print("[SunnyZ] BrightnessController: setBrightness failed (error \(result))")
        }
        return result == 0
    }
}
