//
//  LuxSensorManager.swift
//  SunnyZ
//
//  Enhanced ambient light sensor detection using IOKit ALS APIs
//

import Foundation
import IOKit

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
/// hardware ALS and time-based fallback estimation
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
    private var alsService: io_object_t = 0
    private var lmuService: io_object_t = 0
    private var readingHistory: [Double] = []
    private let historySize = 5
    private var calibrationOffset: Double = 0
    
    private let settings = SettingsManager.shared
    
    // MARK: - IOKit Service Names
    private enum ServiceName {
        static let appleBacklightDisplay = "AppleBacklightDisplay"
        static let appleLMUController = "AppleLMUController"
        static let ioDisplayConnect = "IODisplayConnect"
    }
    
    // MARK: - ALS Property Keys
    private enum ALSKey {
        static let ambientLightSensor = "ALSAmbientLightSensor"
        static let lux = "lux"
        static let channel0 = "Channel0"
        static let channel1 = "Channel1"
    }
    
    // MARK: - Initialization
    
    init() {
        self.calibrationOffset = settings.luxCalibrationOffset
        checkForALSSensor()
    }
    
    deinit {
        // io_object_t is a plain C integer (mach_port_t), not a Swift actor-isolated
        // type, so it is safe to release directly from deinit without a MainActor hop.
        if alsService != 0 {
            IOObjectRelease(alsService)
        }
        if lmuService != 0 {
            IOObjectRelease(lmuService)
        }
    }
    
    // MARK: - ALS Detection
    
    /// Checks if the Mac has an ambient light sensor
    private func checkForALSSensor() {
        // Try AppleBacklightDisplay service
        alsService = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching(ServiceName.appleBacklightDisplay)
        )
        
        // Also try AppleLMUController (older Macs)
        if alsService == 0 {
            lmuService = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching(ServiceName.appleLMUController)
            )
        }
        
        hasALSSensor = (alsService != 0 || lmuService != 0)
        accuracy = hasALSSensor ? .accurate : .estimated
        
        print("[SunnyZ] ALS Sensor detected: \(hasALSSensor)")
    }
    
    // MARK: - Lux Reading
    
    /// Reads the current lux value from the ALS or estimates from context
    func readLux() -> Double {
        // Check for debug override
        if debugOverrideEnabled, let overrideLux = debugOverrideLux {
            accuracy = .accurate
            currentLux = overrideLux
            return overrideLux
        }
        
        var lux: Double
        
        if hasALSSensor {
            lux = readFromALSSensor()
            if lux > 0 {
                accuracy = .accurate
            } else {
                // Sensor exists but returned 0, fall back to estimation
                lux = estimateLuxFromContext()
                accuracy = .estimated
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
    
    /// Reads lux from the actual ALS hardware using IOKit
    private func readFromALSSensor() -> Double {
        var luxValue: Double = 0
        
        // Try AppleBacklightDisplay service first
        if alsService != 0 {
            luxValue = readFromAppleBacklightDisplay(service: alsService)
        }
        
        // Fall back to AppleLMUController if needed
        if luxValue == 0 && lmuService != 0 {
            luxValue = readFromLMUController(service: lmuService)
        }
        
        // If still 0, try creating a fresh service connection
        if luxValue == 0 {
            let freshService = IOServiceGetMatchingService(
                kIOMainPortDefault,
                IOServiceMatching(ServiceName.appleBacklightDisplay)
            )
            
            if freshService != 0 {
                luxValue = readFromAppleBacklightDisplay(service: freshService)
                IOObjectRelease(freshService)
            }
        }
        
        return luxValue
    }
    
    /// Reads from AppleBacklightDisplay service
    private func readFromAppleBacklightDisplay(service: io_object_t) -> Double {
        var luxValue: Double = 0
        
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, nil, 0)
        guard result == KERN_SUCCESS, let props = properties else { return 0 }
        guard let dict = props.takeRetainedValue() as? [String: Any] else { return 0 }
        
        // Try to read ALSAmbientLightSensor property
        if let alsData = dict[ALSKey.ambientLightSensor] as? [String: Any] {
            // Try direct lux value
            if let lux = alsData[ALSKey.lux] as? Double {
                luxValue = lux
            } else if let lux = alsData[ALSKey.lux] as? Int {
                luxValue = Double(lux)
            } else if let lux = alsData[ALSKey.lux] as? Float {
                luxValue = Double(lux)
            }
            
            // If no lux key, try channel values (some Macs use these)
            if luxValue == 0 {
                if let ch0 = alsData[ALSKey.channel0] as? Double,
                   let ch1 = alsData[ALSKey.channel1] as? Double {
                    // Convert channel values to approximate lux
                    luxValue = convertChannelsToLux(ch0: ch0, ch1: ch1)
                }
            }
        }
        
        // Alternative: Try DisplayParameters if no ALS data
        if luxValue == 0,
           let displayParams = dict["DisplayParameters"] as? [String: Any],
           let brightness = displayParams["Brightness"] as? Double {
            // Estimate lux from brightness (very rough approximation)
            luxValue = brightness * 500
        }
        
        return luxValue
    }
    
    /// Reads from AppleLMUController service (older Macs)
    private func readFromLMUController(service: io_object_t) -> Double {
        var luxValue: Double = 0
        
        var properties: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(service, &properties, nil, 0)
        guard result == KERN_SUCCESS, let props = properties else { return 0 }
        guard let dict = props.takeRetainedValue() as? [String: Any] else { return 0 }
        
        // LMUController uses different property structure
        if let sensorData = dict["SensorData"] as? [String: Any] {
            if let lux = sensorData["Lux"] as? Double {
                luxValue = lux
            } else if let lux = sensorData["lux"] as? Double {
                luxValue = lux
            }
        }
        
        // Try raw sensor values
        if luxValue == 0,
           let rawData = dict["RawSensorData"] as? [Int] {
            if rawData.count >= 2 {
                luxValue = convertChannelsToLux(ch0: Double(rawData[0]), ch1: Double(rawData[1]))
            }
        }
        
        return luxValue
    }
    
    /// Converts raw channel values to approximate lux
    /// This is a rough approximation based on typical ALS sensor characteristics
    private func convertChannelsToLux(ch0: Double, ch1: Double) -> Double {
        // Channel 0 is typically visible + IR
        // Channel 1 is typically IR only
        // Visible light ≈ ch0 - ch1
        let visible = max(0, ch0 - ch1)
        
        // Conversion factor varies by sensor, this is an approximation
        let lux = visible * 0.25
        
        return lux
    }
    
    /// Estimates lux based on time of day and other context
    /// Used as fallback when no ALS is available
    private func estimateLuxFromContext() -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())
        let isDaytime = hour >= 7 && hour < 19
        
        // Base lux estimation based on time
        var baseLux: Double
        if isDaytime {
            // Daytime: simulate window light vs direct sunlight
            let isPeakHours = hour >= 10 && hour <= 15
            baseLux = isPeakHours ? 500.0 : 200.0
        } else {
            // Nighttime: indoor lighting only
            baseLux = 30.0
        }
        
        // Add some realistic noise
        let noise = Double.random(in: -10...10)
        let estimatedLux = max(0, baseLux + noise)
        
        return estimatedLux
    }
    
    /// Smooths readings using a moving average
    private func smoothReading(_ newValue: Double) -> Double {
        readingHistory.append(newValue)
        
        // Keep only recent readings
        if readingHistory.count > historySize {
            readingHistory.removeFirst()
        }
        
        // Calculate moving average
        let sum = readingHistory.reduce(0, +)
        return sum / Double(readingHistory.count)
    }
    
    // MARK: - Calibration
    
    /// Starts calibration mode
    func startCalibration() {
        isCalibrating = true
        readingHistory.removeAll()
    }
    
    /// Completes calibration with a reference lux value
    func completeCalibration(referenceLux: Double) {
        let currentReading = currentLux - settings.luxCalibrationOffset
        let offset = referenceLux - currentReading
        
        settings.calibrateLux(currentReading: currentReading, actualLux: referenceLux)
        calibrationOffset = offset
        isCalibrating = false
        
        print("[SunnyZ] Calibration complete. Offset: \(offset)")
    }
    
    /// Cancels calibration
    func cancelCalibration() {
        isCalibrating = false
    }
    
    /// Resets calibration to default
    func resetCalibration() {
        settings.luxCalibrationOffset = 0
        calibrationOffset = 0
    }
    
    // MARK: - Sensor Detection Status
    
    /// Returns a human-readable description of the sensor status
    var sensorStatusDescription: String {
        if hasALSSensor {
            return "Using built-in ambient light sensor"
        } else {
            return "Using time-based estimation (no sensor detected)"
        }
    }
    
    /// Returns detailed sensor info for debugging
    var sensorDetails: String {
        if alsService != 0 {
            return "AppleBacklightDisplay service connected"
        } else if lmuService != 0 {
            return "AppleLMUController service connected"
        } else {
            return "No hardware ALS detected"
        }
    }
    
    // MARK: - Debug
    
    /// Sets the debug override lux value
    func setDebugOverride(_ lux: Double?) {
        debugOverrideLux = lux
    }
    
    /// Clears the debug override
    func clearDebugOverride() {
        debugOverrideLux = nil
        debugOverrideEnabled = false
    }
    
    /// Enables or disables the debug override
    func setDebugOverrideEnabled(_ enabled: Bool) {
        debugOverrideEnabled = enabled
    }
}
