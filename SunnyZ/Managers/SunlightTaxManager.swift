//
//  SunlightTaxManager.swift
//  SunnyZ
//
//  Sunlight Tax - The premium subscription for going outside (macOS)
//

import Foundation
import AppKit
import IOKit
import StoreKit
import Combine

/// Manages the "Sunlight Tax" - charges users for staying indoors too long
/// Late-stage capitalism meets "touch grass"
@MainActor
final class SunlightTaxManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentLux: Double = 0
    @Published var timeInDarkness: TimeInterval = 0
    @Published var taxStatus: TaxStatus = .exempt
    @Published var brightnessLimit: Double = 1.0
    @Published var hasPremiumSubscription: Bool = false
    @Published var totalTaxPaid: Double = 0
    @Published var lastSunlightDate: Date?
    @Published var currentDisplayBrightness: Double = 1.0
    
    // MARK: - Tax Status
    
    enum TaxStatus: Equatable {
        case exempt           // Currently in sunlight
        case warning          // Approaching tax threshold
        case taxed            // Tax applied, brightness limited
        case premium          // Premium subscription active
        
        var description: String {
            switch self {
            case .exempt:
                return "☀️ Sunlight Detected - Tax Exempt"
            case .warning:
                return "⚠️ Cave Dweller Warning"
            case .taxed:
                return "💸 SUNLIGHT TAX ACTIVE"
            case .premium:
                return "👑 Premium Cave Dweller"
            }
        }
        
        var color: String {
            switch self {
            case .exempt: return "#4CAF50"
            case .warning: return "#FF9800"
            case .taxed: return "F44336"
            case .premium: return "#9C27B0"
            }
        }
    }
    
    // MARK: - Constants
    
    /// Lux threshold for "sunlight" (outdoor/indoor with windows)
    let sunlightThreshold: Double = 100
    
    /// Lux threshold for "darkness" (cave dwelling)
    let darknessThreshold: Double = 50
    
    /// Time before tax kicks in (4 hours)
    let taxThreshold: TimeInterval = 4 * 60 * 60
    
    /// Warning threshold (3.5 hours)
    let warningThreshold: TimeInterval = 3.5 * 60 * 60
    
    /// Brightness limit when taxed (50%)
    let taxedBrightnessLimit: Double = 0.5
    
    /// Tax amount per unlock
    let taxAmount: Decimal = 0.99
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var darknessStartTime: Date?
    private var timer: Timer?
    private var displayService: io_object_t = 0
    
    // UserDefaults keys
    private let kTotalTaxPaid = "sunlightTax.totalPaid"
    private let kLastSunlightDate = "sunlightTax.lastSunlight"
    private let kHasPremium = "sunlightTax.hasPremium"
    
    // MARK: - Initialization
    
    init() {
        loadSavedState()
        setupDisplayConnection()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        if displayService != 0 {
            IOObjectRelease(displayService)
        }
    }
    
    // MARK: - Setup
    
    private func loadSavedState() {
        totalTaxPaid = UserDefaults.standard.double(forKey: kTotalTaxPaid)
        hasPremiumSubscription = UserDefaults.standard.bool(forKey: kHasPremium)
        if let date = UserDefaults.standard.object(forKey: kLastSunlightDate) as? Date {
            lastSunlightDate = date
        }
    }
    
    private func setupDisplayConnection() {
        // Get IOKit connection to control display brightness
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect")
        )
        displayService = service
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSunlightStatus()
            }
        }
        
        // Initial update
        updateSunlightStatus()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Sunlight Detection
    
    private func updateSunlightStatus() {
        // Read ambient light sensor on Mac
        let lux = readAmbientLightSensor()
        currentLux = lux
        
        // Update current display brightness
        currentDisplayBrightness = getDisplayBrightness()
        
        // Check if we're in sunlight
        if lux >= sunlightThreshold {
            handleSunlightDetected()
        } else if lux <= darknessThreshold {
            handleDarknessDetected()
        }
        
        // Update tax status
        updateTaxStatus()
        
        // Enforce brightness limits
        enforceBrightnessLimit()
    }
    
    private func readAmbientLightSensor() -> Double {
        // On macOS, we can read the ambient light sensor via IOKit
        // This is the legitimate way to access ALS on Mac
        
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleBacklightDisplay")
        )
        
        guard service != 0 else {
            // Fallback: estimate based on time of day if no sensor
            return estimateLuxFromContext()
        }
        
        // Try to read the sensor value
        var luxValue: Double = 0
        
        if let dict = IORegistryEntryCreateCFProperties(
            service,
            nil,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? [String: Any] {
            
            // Look for ambient light sensor data
            if let alsData = dict["ALSAmbientLightSensor"] as? [String: Any],
               let lux = alsData["lux"] as? Double {
                luxValue = lux
            } else if let displayParams = dict["DisplayParameters"] as? [String: Any],
                      let brightness = displayParams["Brightness"] as? Double {
                // Estimate lux from brightness setting
                luxValue = brightness * 500
            }
        }
        
        IOObjectRelease(service)
        
        // If we couldn't read sensor, use context estimation
        if luxValue == 0 {
            luxValue = estimateLuxFromContext()
        }
        
        return luxValue
    }
    
    private func estimateLuxFromContext() -> Double {
        // Fallback estimation based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        
        // Rough daylight hours estimation
        let isDaytime = hour >= 7 && hour < 19
        
        // Add some randomness to simulate sensor readings
        let baseLux = isDaytime ? 200.0 : 10.0
        let noise = Double.random(in: -20...20)
        
        return max(0, baseLux + noise)
    }
    
    private func handleSunlightDetected() {
        lastSunlightDate = Date()
        UserDefaults.standard.set(Date(), forKey: kLastSunlightDate)
        
        darknessStartTime = nil
        timeInDarkness = 0
        
        // Reset brightness limit
        brightnessLimit = 1.0
    }
    
    private func handleDarknessDetected() {
        if darknessStartTime == nil {
            darknessStartTime = Date()
        }
        
        if let startTime = darknessStartTime {
            timeInDarkness = Date().timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Tax Logic
    
    private func updateTaxStatus() {
        if hasPremiumSubscription {
            taxStatus = .premium
            brightnessLimit = 1.0
            return
        }
        
        if timeInDarkness >= taxThreshold {
            taxStatus = .taxed
            brightnessLimit = taxedBrightnessLimit
        } else if timeInDarkness >= warningThreshold {
            taxStatus = .warning
            brightnessLimit = 1.0
        } else {
            taxStatus = .exempt
            brightnessLimit = 1.0
        }
    }
    
    // MARK: - Display Brightness Control
    
    private func getDisplayBrightness() -> Double {
        guard displayService != 0 else { return 1.0 }
        
        var brightness: Float = 1.0
        IODisplayGetFloatParameter(
            displayService,
            kIODisplayBrightnessKey as CFString,
            &brightness
        )
        
        return Double(brightness)
    }
    
    private func setDisplayBrightness(_ value: Double) {
        guard displayService != 0 else { return }
        
        let clampedValue = max(0, min(1, Float(value)))
        
        IODisplaySetFloatParameter(
            displayService,
            kIODisplayBrightnessKey as CFString,
            clampedValue
        )
    }
    
    private func enforceBrightnessLimit() {
        guard taxStatus == .taxed else { return }
        
        let currentBrightness = getDisplayBrightness()
        if currentBrightness > brightnessLimit {
            setDisplayBrightness(brightnessLimit)
        }
    }
    
    // MARK: - StoreKit Integration
    
    /// Pay the sunlight tax to unlock brightness temporarily
    func payTax() async throws {
        // Simulate the purchase
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Unlock brightness for 1 hour
        brightnessLimit = 1.0
        setDisplayBrightness(1.0)
        
        totalTaxPaid += Double(truncating: taxAmount as NSNumber)
        UserDefaults.standard.set(totalTaxPaid, forKey: kTotalTaxPaid)
        
        // Schedule re-tax after 1 hour
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) { [weak self] in
            self?.updateTaxStatus()
        }
    }
    
    /// Purchase premium subscription (unlimited cave dwelling)
    func purchasePremium() async throws {
        // Simulate premium purchase
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        hasPremiumSubscription = true
        UserDefaults.standard.set(true, forKey: kHasPremium)
        brightnessLimit = 1.0
        setDisplayBrightness(1.0)
        taxStatus = .premium
    }
    
    // MARK: - Statistics
    
    var formattedTimeInDarkness: String {
        let hours = Int(timeInDarkness) / 3600
        let minutes = Int(timeInDarkness) % 3600 / 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    var formattedTotalTax: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: totalTaxPaid)) ?? "$0.00"
    }
    
    var timeUntilTax: TimeInterval {
        max(0, taxThreshold - timeInDarkness)
    }
    
    var formattedTimeUntilTax: String {
        let minutes = Int(timeUntilTax) / 60
        return "\(minutes) min"
    }
}
