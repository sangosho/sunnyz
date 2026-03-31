//
//  LuxSensorManager.swift
//  SunnyZ
//
//  Ambient light sensor detection using IOHIDManager.
//
//  On Apple Silicon the ALS is an AppleSPUHIDInterface device (HID),
//  not a traditional IOKit service. Access requires root privileges;
//  we detect availability at init and fall back to time-based
//  estimation when the HID device is inaccessible.
//

import Foundation
import IOKit
import IOKit.hid

/// Represents the accuracy/state of lux readings
enum LuxAccuracy: Equatable {
    case accurate      // Reading from actual ALS sensor
    case estimated     // Time-based estimation
    case unavailable   // No sensor and estimation failed

    var displayText: String {
        switch self {
        case .accurate: return "Accurate"
        case .estimated: return "Estimated"
        case .unavailable: return "Unavailable"
        }
    }

    var icon: String {
        switch self {
        case .accurate: return "checkmark.circle.fill"
        case .estimated: return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .accurate: return "green"
        case .estimated: return "orange"
        case .unavailable: return "red"
        }
    }
}

/// Manages ambient light sensor readings with support for both
/// hardware ALS (IOHIDManager) and time-based fallback estimation.
@MainActor
final class LuxSensorManager: ObservableObject {

    static let shared = LuxSensorManager()

    // MARK: - Published State
    @Published var currentLux: Double = 0
    @Published var accuracy: LuxAccuracy = .estimated
    @Published var isCalibrating: Bool = false
    @Published var hasALSSensor: Bool = false

    // MARK: - Debug
    @Published var debugOverrideLux: Double?
    @Published var debugOverrideEnabled: Bool = false

    // MARK: - Private Properties
    nonisolated(unsafe) private var hidManager: IOHIDManager?
    private var readingHistory: [Double] = []
    private let historySize = 5
    private var calibrationOffset: Double = 0
    private var latestRawLux: Double?

    private let settings = SettingsManager.shared

    // MARK: - Initialization

    init() {
        self.calibrationOffset = settings.luxCalibrationOffset
        setupALSSensor()
    }

    deinit {
        // IOHIDManager is a CFType that can be released from deinit.
        // Using nonisolated(unsafe) would require storing it as such,
        // so we release directly — IOHIDManagerClose is thread-safe.
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    // MARK: - HID ALS Setup (Apple Silicon)

    /// Attempts to open the ambient light sensor via IOHIDManager.
    /// On Apple Silicon the ALS is an AppleSPUHIDInterface HID device.
    private func setupALSSensor() {
        // Create HID manager
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard CFGetTypeID(manager) == IOHIDManagerGetTypeID() else {
            print("[SunnyZ] ALS: Could not create IOHIDManager")
            return
        }

        // Match Apple's SPU HID device for ALS
        // Usage page 0xFF00 (Vendor Specific), usage 4 (ALS)
        let matchDict: [String: Any] = [
            "VendorID": 0x05AC,                          // Apple
            "DeviceUsagePage": 0xFF00,                    // Vendor Specific
            "DeviceUsage": 4                              // ALS
        ]

        IOHIDManagerSetDeviceMatching(manager, matchDict as CFDictionary)

        // Open the manager — requires root on Apple Silicon
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult != kIOReturnSuccess {
            print("[SunnyZ] ALS: IOHIDManagerOpen failed (error \(openResult)). "
                  + "Sensor access requires root privileges — using time-based estimation.")
            // Try legacy IOKit path as secondary fallback (Intel)
            checkLegacyALSSensor()
            return
        }

        // Try to get the matched device
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let device = deviceSet.first else {
            print("[SunnyZ] ALS: No matching HID device found")
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            // Try legacy IOKit path
            checkLegacyALSSensor()
            return
        }

        // Successfully connected to ALS HID device
        hasALSSensor = true
        accuracy = .accurate
        hidManager = manager

        // Try an initial read
        let lux = readFromHIDDevice(device)
        if lux > 0 {
            latestRawLux = lux
            let calibrated = settings.applyCalibration(to: lux)
            currentLux = smoothReading(calibrated)
        }

        print("[SunnyZ] ALS: Apple Silicon HID sensor connected successfully")
    }

    /// Reads lux from an opened AppleSPUHIDDevice.
    /// The device returns a 22-byte HID report with a lux value and
    /// 4 spectral channels (each int32 little-endian, scaled by 65536).
    private func readFromHIDDevice(_ device: IOHIDDevice) -> Double {
        var report = [UInt8](repeating: 0, count: 32)
        var reportLength: CFIndex = 32

        // Try to read a report from the device
        let result = IOHIDDeviceGetReport(
            device,
            kIOHIDReportTypeInput,
            0,          // reportID
            &report,
            &reportLength
        )

        if result == kIOReturnSuccess && reportLength > 0 {
            return parseALSReport(report, length: Int(reportLength))
        }

        return 0
    }

    /// Parses the ALS HID report structure.
    ///
    /// Expected layout (22+ bytes):
    ///   Bytes 0-5:   Header / timestamp
    ///   Bytes 6-9:   Lux value (int32 LE, divide by 65536 for lux)
    ///   Bytes 10-25: 4 spectral channels (int32 LE each, divide by 65536)
    private func parseALSReport(_ report: [UInt8], length: Int) -> Double {
        guard length >= 10 else { return 0 }

        // Lux value at byte offset 6 (int32 little-endian)
        let luxOffset = 6
        guard luxOffset + 4 <= length else { return 0 }

        let luxRaw = Int32(report[luxOffset])
            | (Int32(report[luxOffset + 1]) << 8)
            | (Int32(report[luxOffset + 2]) << 16)
            | (Int32(report[luxOffset + 3]) << 24)

        // Scale from fixed-point (divide by 65536)
        let lux = Double(luxRaw) / 65536.0
        return max(0, lux)
    }

    // MARK: - Legacy IOKit ALS (Intel fallback)

    /// Checks for ALS via the legacy IOKit path (Intel-era Macs).
    private func checkLegacyALSSensor() {
        let alsService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleBacklightDisplay")
        )

        let lmuService: io_object_t
        if alsService != 0 {
            lmuService = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching("AppleLMUController")
            )
        } else {
            lmuService = 0
        }

        let found = (alsService != 0 || lmuService != 0)
        if found {
            hasALSSensor = true
            accuracy = .accurate
            print("[SunnyZ] ALS: Legacy IOKit sensor detected")
        } else {
            hasALSSensor = false
            accuracy = .estimated
            print("[SunnyZ] ALS: No sensor found — using time-based estimation")
        }

        if alsService != 0 { IOObjectRelease(alsService) }
        if lmuService != 0 { IOObjectRelease(lmuService) }
    }

    /// Reads from legacy IOKit ALS service (Intel Macs).
    private func readFromLegacySensor() -> Double {
        var luxValue: Double = 0

        // AppleBacklightDisplay
        let alsService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleBacklightDisplay")
        )
        if alsService != 0 {
            luxValue = readFromAppleBacklightDisplay(service: alsService)
            IOObjectRelease(alsService)
        }

        if luxValue > 0 { return luxValue }

        // AppleLMUController
        let lmuService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleLMUController")
        )
        if lmuService != 0 {
            luxValue = readFromLMUController(service: lmuService)
            IOObjectRelease(lmuService)
        }

        return luxValue
    }

    private func readFromAppleBacklightDisplay(service: io_object_t) -> Double {
        var luxValue: Double = 0

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, nil, 0)
        guard result == KERN_SUCCESS, let props = properties else { return 0 }
        guard let dict = props.takeRetainedValue() as? [String: Any] else { return 0 }

        if let alsData = dict["ALSAmbientLightSensor"] as? [String: Any] {
            if let lux = alsData["lux"] as? Double {
                luxValue = lux
            } else if let lux = alsData["lux"] as? Int {
                luxValue = Double(lux)
            } else if let lux = alsData["lux"] as? Float {
                luxValue = Double(lux)
            }

            if luxValue == 0,
               let ch0 = alsData["Channel0"] as? Double,
               let ch1 = alsData["Channel1"] as? Double {
                luxValue = convertChannelsToLux(ch0: ch0, ch1: ch1)
            }
        }

        if luxValue == 0,
           let displayParams = dict["DisplayParameters"] as? [String: Any],
           let brightness = displayParams["Brightness"] as? Double {
            luxValue = brightness * 500
        }

        return luxValue
    }

    private func readFromLMUController(service: io_object_t) -> Double {
        var luxValue: Double = 0

        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, nil, 0)
        guard result == KERN_SUCCESS, let props = properties else { return 0 }
        guard let dict = props.takeRetainedValue() as? [String: Any] else { return 0 }

        if let sensorData = dict["SensorData"] as? [String: Any] {
            if let lux = sensorData["Lux"] as? Double {
                luxValue = lux
            } else if let lux = sensorData["lux"] as? Double {
                luxValue = lux
            }
        }

        if luxValue == 0,
           let rawData = dict["RawSensorData"] as? [Int],
           rawData.count >= 2 {
            luxValue = convertChannelsToLux(ch0: Double(rawData[0]), ch1: Double(rawData[1]))
        }

        return luxValue
    }

    private func convertChannelsToLux(ch0: Double, ch1: Double) -> Double {
        let visible = max(0, ch0 - ch1)
        return visible * 0.25
    }

    // MARK: - HID Cleanup

    private func teardownHIDManager() {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            hidManager = nil
        }
    }

    // MARK: - Public Lux Reading

    /// Reads the current lux value from the ALS or estimates from context.
    func readLux() -> Double {
        // Check for debug override
        if debugOverrideEnabled, let overrideLux = debugOverrideLux {
            accuracy = .accurate
            currentLux = overrideLux
            return overrideLux
        }

        var lux: Double

        if hasALSSensor {
            // Try HID sensor first (Apple Silicon)
            if let manager = hidManager,
               let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
               let device = deviceSet.first {
                lux = readFromHIDDevice(device)
                if lux > 0 {
                    accuracy = .accurate
                } else {
                    lux = readFromLegacySensor()
                    if lux > 0 {
                        accuracy = .accurate
                    } else {
                        lux = estimateLuxFromContext()
                        accuracy = .estimated
                    }
                }
            } else {
                // Legacy path
                lux = readFromLegacySensor()
                if lux > 0 {
                    accuracy = .accurate
                } else {
                    lux = estimateLuxFromContext()
                    accuracy = .estimated
                }
            }
        } else {
            lux = estimateLuxFromContext()
            accuracy = .estimated
        }

        // Apply calibration offset
        let calibratedLux = settings.applyCalibration(to: lux)

        // Smooth readings with moving average
        let smoothedLux = smoothReading(calibratedLux)

        currentLux = smoothedLux
        return smoothedLux
    }

    /// Estimates lux based on time of day and other context.
    private func estimateLuxFromContext() -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let isDaytime = hour >= 7 && hour < 19

        var baseLux: Double
        if isDaytime {
            let isPeakHours = hour >= 10 && hour <= 15
            baseLux = isPeakHours ? 500.0 : 200.0
        } else {
            baseLux = 30.0
        }

        let noise = Double.random(in: -10...10)
        return max(0, baseLux + noise)
    }

    /// Smooths readings using a moving average.
    private func smoothReading(_ newValue: Double) -> Double {
        readingHistory.append(newValue)
        if readingHistory.count > historySize {
            readingHistory.removeFirst()
        }
        let sum = readingHistory.reduce(0, +)
        return sum / Double(readingHistory.count)
    }

    // MARK: - Calibration

    func startCalibration() {
        isCalibrating = true
        readingHistory.removeAll()
    }

    func completeCalibration(referenceLux: Double) {
        let currentReading = currentLux - settings.luxCalibrationOffset
        let offset = referenceLux - currentReading

        settings.calibrateLux(currentReading: currentReading, actualLux: referenceLux)
        calibrationOffset = offset
        isCalibrating = false

        print("[SunnyZ] Calibration complete. Offset: \(offset)")
    }

    func cancelCalibration() {
        isCalibrating = false
    }

    func resetCalibration() {
        settings.luxCalibrationOffset = 0
        calibrationOffset = 0
    }

    // MARK: - Sensor Status

    var sensorStatusDescription: String {
        if hasALSSensor {
            return hidManager != nil
                ? "Using Apple Silicon HID ambient light sensor"
                : "Using built-in ambient light sensor"
        } else {
            return "Using time-based estimation (no sensor detected)"
        }
    }

    var sensorDetails: String {
        if hidManager != nil {
            return "AppleSPUHIDInterface connected via IOHIDManager"
        } else if hasALSSensor {
            return "Legacy IOKit ALS service connected"
        } else {
            return "No hardware ALS detected"
        }
    }

    // MARK: - Debug

    func setDebugOverride(_ lux: Double?) {
        debugOverrideLux = lux
    }

    func clearDebugOverride() {
        debugOverrideLux = nil
        debugOverrideEnabled = false
    }

    func setDebugOverrideEnabled(_ enabled: Bool) {
        debugOverrideEnabled = enabled
    }
}
