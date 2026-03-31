//
//  EnvironmentClassifier.swift
//  SunnyZ
//
//  Multi-signal indoor/outdoor classifier using:
//    1. Screen brightness (primary) — via DisplayServices
//    2. Wi-Fi density + stability (co-primary, veto) — via CoreWLAN
//    3. Power + thermal pressure (supporting) — via IOKit/ProcessInfo
//
//  Uses agreement + veto logic with temporal smoothing and
//  baseline calibration per user.
//

import Foundation
import CoreWLAN
import IOKit
import Combine

// MARK: - Types

/// Classified environment state.
enum EnvironmentState: Equatable {
    case outdoor
    case indoor
    case uncertain

    var isDarkness: Bool {
        self == .indoor || self == .uncertain
    }

    var label: String {
        switch self {
        case .outdoor: return "Outdoor"
        case .indoor: return "Indoor"
        case .uncertain: return "Uncertain"
        }
    }
}

/// Snapshot of all sensor signals at one point in time.
struct SignalSnapshot: Sendable {
    let brightness: Double          // 0.0...1.0
    let brightnessDelta: Double     // change over last sample
    let wifiCount: Int              // visible networks
    let wifiRssiVariance: Double    // spread of signal strengths
    let wifiStable: Bool            // same network for a while
    let onBattery: Bool
    let batteryLevel: Int           // 0...100
    let thermalStateRaw: Int        // 0=nominal, 1=fair, 2=serious, 3=critical

    /// Strength of thermal state (0.0...1.0)
    var thermalPressure: Double {
        Double(thermalStateRaw) / 3.0
    }
}

// MARK: - Baseline

/// Learns the user's typical indoor environment over time.
@MainActor
struct UserBaseline: Codable {
    var typicalBrightness: Double = 0.5
    var typicalWifiCount: Int = 3
    var sampleCount: Int = 0

    /// Update baseline with a new observation using exponential moving average.
    mutating func update(brightness: Double, wifiCount: Int) {
        let alpha: Double = 0.05 // slow adaptation
        typicalBrightness = typicalBrightness * (1 - alpha) + brightness * alpha
        typicalWifiCount = Int(Double(typicalWifiCount) * (1 - alpha) + Double(wifiCount) * alpha)
        sampleCount += 1
    }

    static let kBaselineBrightness = "envClassifier.baselineBrightness"
    static let kBaselineWifiCount = "envClassifier.baselineWifiCount"
    static let kBaselineSampleCount = "envClassifier.baselineSampleCount"

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(typicalBrightness, forKey: Self.kBaselineBrightness)
        defaults.set(typicalWifiCount, forKey: Self.kBaselineWifiCount)
        defaults.set(sampleCount, forKey: Self.kBaselineSampleCount)
    }

    static func load() -> UserBaseline {
        let defaults = UserDefaults.standard
        var baseline = UserBaseline()
        if defaults.object(forKey: kBaselineBrightness) != nil {
            baseline.typicalBrightness = defaults.double(forKey: kBaselineBrightness)
            baseline.typicalWifiCount = defaults.integer(forKey: kBaselineWifiCount)
            baseline.sampleCount = defaults.integer(forKey: kBaselineSampleCount)
        }
        return baseline
    }
}

// MARK: - EnvironmentClassifier

@MainActor
final class EnvironmentClassifier: ObservableObject {

    static let shared = EnvironmentClassifier()

    // MARK: - Published State

    @Published var currentState: EnvironmentState = .uncertain
    @Published var confidence: Double = 0.0
    @Published var lastSnapshot: SignalSnapshot?
    @Published var currentBrightness: Double = 0.5
    @Published var wifiNetworkCount: Int = 0

    // MARK: - Classification History (for temporal smoothing)

    private var stateHistory: [EnvironmentState] = []
    private let smoothWindow = 5 // need N consecutive same-class to commit

    // MARK: - Brightness History (for delta calculation)

    private var brightnessHistory: [Double] = []
    private let brightnessHistorySize = 6

    // MARK: - Wi-Fi History (for variance)

    private var wifiHistory: [[String: Int]] = [] // [[ssid: rssi]]
    private let wifiHistorySize = 3

    // MARK: - Baseline

    private var baseline = UserBaseline.load()

    // MARK: - Calibration

    /// After enough samples, the classifier trusts its readings.
    var isCalibrated: Bool {
        baseline.sampleCount >= 10
    }

    // MARK: - Settings

    private var timeOfDayFactor: Double {
        let hour = Calendar.current.component(.hour, from: Date())
        // Nighttime (22:00–06:00) — assume indoor
        if hour >= 22 || hour < 6 { return -1.0 }
        // Late night (20:00–22:00) — slightly indoor-leaning
        if hour >= 20 { return -0.3 }
        return 0.0
    }

    // MARK: - Signal Collection

    // MARK: - Wi-Fi Cache (avoids blocking main thread)

    private var cachedWifiCount: Int = 0
    private var cachedWifiVariance: Double = 0
    private var cachedWifiStable: Bool = false
    private var lastWifiScanTime: Date = .distantPast
    private let wifiScanInterval: TimeInterval = 30 // re-scan every 30 seconds
    private var wifiScanInProgress = false

    /// Collects all signals and returns the current snapshot.
    /// Wi-Fi scanning runs on a background thread; all other signals
    /// are cheap reads that stay on the main actor.
    func collectSignals() -> SignalSnapshot {
        let brightness = readBrightness()
        let delta = brightnessDelta(for: brightness)
        let power = readPower()

        // Use cached Wi-Fi data — re-scan in background if stale
        if Date().timeIntervalSince(lastWifiScanTime) > wifiScanInterval && !wifiScanInProgress {
            wifiScanInProgress = true
            Task.detached {
                let wifi = self.performWiFiScan()
                await MainActor.run { [weak self] in
                    self?.cachedWifiCount = wifi.count
                    self?.cachedWifiVariance = wifi.variance
                    self?.cachedWifiStable = wifi.stable
                    self?.wifiHistory.append(contentsOf: wifi.snapshot)
                    if let count = self?.wifiHistory.count, count > self?.wifiHistorySize ?? 3 {
                        self?.wifiHistory.removeFirst()
                    }
                    self?.lastWifiScanTime = Date()
                    self?.wifiScanInProgress = false
                }
            }
        }

        let snapshot = SignalSnapshot(
            brightness: brightness,
            brightnessDelta: delta,
            wifiCount: cachedWifiCount,
            wifiRssiVariance: cachedWifiVariance,
            wifiStable: cachedWifiStable,
            onBattery: power.onBattery,
            batteryLevel: power.level,
            thermalStateRaw: power.thermalRaw
        )

        lastSnapshot = snapshot
        currentBrightness = brightness
        wifiNetworkCount = cachedWifiCount

        return snapshot
    }

    /// Classifies the current environment and returns the state.
    /// Uses temporal smoothing — requires `smoothWindow` consecutive
    /// same-class readings before committing.
    func classify() -> EnvironmentState {
        let snapshot = collectSignals()
        let raw = classifyRaw(snapshot)

        // Temporal smoothing
        stateHistory.append(raw)
        if stateHistory.count > smoothWindow {
            stateHistory.removeFirst()
        }

        // Require majority agreement
        let outdoorCount = stateHistory.filter { $0 == .outdoor }.count
        let indoorCount = stateHistory.filter { $0 == .indoor }.count
        let _ = stateHistory.filter { $0 == .uncertain }.count

        let threshold = smoothWindow / 2 + 1
        if outdoorCount >= threshold {
            currentState = .outdoor
            confidence = Double(outdoorCount) / Double(smoothWindow)
        } else if indoorCount >= threshold {
            currentState = .indoor
            confidence = Double(indoorCount) / Double(smoothWindow)
        } else {
            currentState = .uncertain
            confidence = 0.3
        }

        // Update baseline when we're confident it's indoor
        if currentState == .indoor && confidence >= 0.6 {
            baseline.update(brightness: snapshot.brightness, wifiCount: snapshot.wifiCount)
            if baseline.sampleCount % 20 == 0 {
                baseline.save()
            }
        }

        return currentState
    }

    /// Resets classification history (e.g. after a state change).
    func resetSmoothing() {
        stateHistory.removeAll()
        brightnessHistory.removeAll()
    }

    // MARK: - Raw Classification

    private func classifyRaw(_ s: SignalSnapshot) -> EnvironmentState {
        var outdoorScore: Double = 0
        var indoorScore: Double = 0

        // ── 1. BRIGHTNESS (primary) ──
        if s.brightness > 0.85 { outdoorScore += 3 }
        else if s.brightness > 0.7 { outdoorScore += 1 }

        if s.brightnessDelta > 0.1 { outdoorScore += 1.5 }
        if s.brightness < 0.3 { indoorScore += 2 }

        // ── 2. WI-FI (DOMINANT SIGNAL) ──
        // Wi-Fi density is the strongest indicator of indoor/outdoor
        if s.wifiCount >= 8 {
            indoorScore += 5        // Very strong indoor (office/home)
        } else if s.wifiCount >= 5 {
            indoorScore += 3        // Moderate indoor
        } else if s.wifiCount <= 1 {
            outdoorScore += 4       // Very strong outdoor (park/street)
        } else if s.wifiCount <= 2 {
            outdoorScore += 2       // Weak outdoor
        }

        // High variance = moving = outdoor-leaning (but only if not strongly indoor)
        if s.wifiRssiVariance > 100 && s.wifiCount < 5 {
            outdoorScore += 1
        }

        // ── 3. POWER + THERMAL (weak supporting) ──
        if s.onBattery && s.brightness > 0.75 && s.wifiCount < 5 {
            outdoorScore += 1
        } else if !s.onBattery && s.wifiCount >= 4 {
            indoorScore += 0.5
        }

        if s.thermalPressure >= 0.5 && s.brightness > 0.7 && s.wifiCount < 5 {
            outdoorScore += 0.5
        }

        // ── 4. TIME OF DAY (weak correction) ──
        let tod = timeOfDayFactor
        if tod < 0 { indoorScore += abs(tod) }
        if tod > 0 { outdoorScore += tod * 0.5 }

        // ── 5. DECISION ──
        // Wi-Fi is the dominant signal. If scores are very close,
        // default to indoor (safer for sunlight tax purposes).
        let diff = abs(outdoorScore - indoorScore)
        if diff < 1.0 {
            // Too close to call — use Wi-Fi count as tiebreaker
            return s.wifiCount >= 4 ? .indoor : .outdoor
        }

        if indoorScore > outdoorScore {
            return .indoor
        } else {
            return .outdoor
        }
    }

    // MARK: - Signal Readers

    private func readBrightness() -> Double {
        return BrightnessController.shared.getBrightness() ?? 0.5
    }

    private func brightnessDelta(for newBrightness: Double) -> Double {
        brightnessHistory.append(newBrightness)
        if brightnessHistory.count > brightnessHistorySize {
            brightnessHistory.removeFirst()
        }
        guard brightnessHistory.count >= 2 else { return 0 }
        let old = brightnessHistory[brightnessHistory.count - 2]
        return newBrightness - old
    }

    /// Performs a Wi-Fi scan (called from background thread).
    /// CoreWLAN scanForNetworks can take 1-2 seconds.
    nonisolated private func performWiFiScan() -> (count: Int, variance: Double, stable: Bool, snapshot: [[String: Int]]) {
        let client = CWWiFiClient.shared()
        guard let iface = client.interfaces()?.first else {
            return (0, 0, false, [])
        }

        do {
            let networks = try iface.scanForNetworks(withSSID: nil, includeHidden: false)
            let count = networks.count

            // Calculate RSSI variance
            let rssis = networks.map { Double($0.rssiValue) }
            let v = rssis.isEmpty ? 0 : computeVariance(rssis)

            // Stability: is variance low?
            let stable = v < 50

            // Build snapshot for history (returned, not stored here)
            var snapshot: [[String: Int]] = []
            for net in networks {
                if let ssid = net.ssid {
                    snapshot.append([ssid: net.rssiValue])
                }
            }

            return (count, v, stable, snapshot)
        } catch {
            return (0, 0, false, [])
        }
    }

    nonisolated private func computeVariance(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Double(values.count)
    }

    private func readPower() -> (onBattery: Bool, level: Int, thermalRaw: Int) {
        // Thermal state from ProcessInfo
        let thermalRaw = ProcessInfo.processInfo.thermalState.rawValue

        // Battery level — IOPSCarbon functions aren't available in Swift's IOKit module,
        // so we use the IOPS private framework via dlsym.
        var onBattery = true
        var level = 100

        if let handle = dlopen("/System/Library/PrivateFrameworks/IOPSCarbon.framework/IOPSCarbon", RTLD_LAZY) {
            typealias CopyInfoFn = @convention(c) () -> Unmanaged<AnyObject>
            typealias CopyListFn = @convention(c) (AnyObject) -> Unmanaged<AnyObject>
            typealias GetDescFn = @convention(c) (AnyObject, AnyObject) -> Unmanaged<AnyObject>

            let copyInfoRaw = dlsym(handle, "IOPSCopyPowerSourcesInfo")
            let copyListRaw = dlsym(handle, "IOPSCopyPowerSourcesList")
            let getDescRaw = dlsym(handle, "IOPSGetPowerSourceDescription")

            if copyInfoRaw != nil, copyListRaw != nil, getDescRaw != nil {
                let copyInfo = unsafeBitCast(copyInfoRaw, to: CopyInfoFn.self)
                let copyList = unsafeBitCast(copyListRaw, to: CopyListFn.self)
                let getDesc = unsafeBitCast(getDescRaw, to: GetDescFn.self)

                let info = copyInfo().takeRetainedValue()
                let list = (copyList(info).takeRetainedValue() as? [Any]) ?? []

                for item in list {
                    let desc = (getDesc(info, item as AnyObject).takeRetainedValue() as? [String: Any])
                    if let current = desc?["Current Capacity" as String] as? Int { level = current }
                    if let charging = desc?["Is Charging" as String] as? Bool { onBattery = !charging }
                    if let powerType = desc?["Type" as String] as? String, powerType == "AC Power" { onBattery = false }
                }
            }
            dlclose(handle)
        }

        return (onBattery, level, thermalRaw)
    }

    // MARK: - Debug

    var debugDescription: String {
        guard let s = lastSnapshot else { return "No snapshot" }
        return """
        Environment: \(currentState.label) (confidence: \(String(format: "%.0f", confidence * 100))%)
        Brightness: \(String(format: "%.2f", s.brightness)) (delta: \(String(format: "%+.2f", s.brightnessDelta)))
        WiFi: \(s.wifiCount) networks, variance: \(String(format: "%.1f", s.wifiRssiVariance))
        Power: \(s.onBattery ? "battery \(s.batteryLevel)%" : "AC") thermal=\(s.thermalStateRaw)
        Baseline: brightness=\(String(format: "%.2f", baseline.typicalBrightness)) wifi=\(baseline.typicalWifiCount) (\(baseline.sampleCount) samples)
        """
    }
}
