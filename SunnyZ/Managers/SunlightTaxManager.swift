//
//  SunlightTaxManager.swift
//  SunnyZ
//
//  Sunlight Tax - Menu bar edition
//

import Foundation
import AppKit
import IOKit
import Combine

/// Manages the "Sunlight Tax" - charges users for staying indoors too long
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
        case exempt
        case warning
        case taxed
        case premium
        
        var icon: String {
            switch self {
            case .exempt: return "☀️"
            case .warning: return "🌤️"
            case .taxed: return "💸"
            case .premium: return "👑"
            }
        }
        
        var menuIcon: String {
            switch self {
            case .exempt: return "sun.max.fill"
            case .warning: return "cloud.sun.fill"
            case .taxed: return "dollarsign.circle.fill"
            case .premium: return "crown.fill"
            }
        }
        
        var color: NSColor {
            switch self {
            case .exempt: return .systemYellow
            case .warning: return .systemOrange
            case .taxed: return .systemRed
            case .premium: return .systemPurple
            }
        }
    }
    
    // MARK: - Constants
    
    let sunlightThreshold: Double = 100
    let darknessThreshold: Double = 50
    let taxThreshold: TimeInterval = 4 * 60 * 60
    let warningThreshold: TimeInterval = 3.5 * 60 * 60
    let taxedBrightnessLimit: Double = 0.5
    let taxAmount: Decimal = 0.99
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var darknessStartTime: Date?
    private var timer: Timer?
    private var displayService: io_object_t = 0
    
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
    
    private func loadSavedState() {
        totalTaxPaid = UserDefaults.standard.double(forKey: kTotalTaxPaid)
        hasPremiumSubscription = UserDefaults.standard.bool(forKey: kHasPremium)
        if let date = UserDefaults.standard.object(forKey: kLastSunlightDate) as? Date {
            lastSunlightDate = date
        }
    }
    
    private func setupDisplayConnection() {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IODisplayConnect")
        )
        displayService = service
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSunlightStatus()
            }
        }
        updateSunlightStatus()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateSunlightStatus() {
        let lux = readAmbientLightSensor()
        currentLux = lux
        currentDisplayBrightness = getDisplayBrightness()
        
        if lux >= sunlightThreshold {
            handleSunlightDetected()
        } else if lux <= darknessThreshold {
            handleDarknessDetected()
        }
        
        updateTaxStatus()
        enforceBrightnessLimit()
    }
    
    private func readAmbientLightSensor() -> Double {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleBacklightDisplay")
        )
        
        guard service != 0 else {
            return estimateLuxFromContext()
        }
        
        var luxValue: Double = 0
        
        if let dict = IORegistryEntryCreateCFProperties(
            service,
            nil,
            kCFAllocatorDefault,
            0
        ).takeRetainedValue() as? [String: Any] {
            
            if let alsData = dict["ALSAmbientLightSensor"] as? [String: Any],
               let lux = alsData["lux"] as? Double {
                luxValue = lux
            } else if let displayParams = dict["DisplayParameters"] as? [String: Any],
                      let brightness = displayParams["Brightness"] as? Double {
                luxValue = brightness * 500
            }
        }
        
        IOObjectRelease(service)
        
        if luxValue == 0 {
            luxValue = estimateLuxFromContext()
        }
        
        return luxValue
    }
    
    private func estimateLuxFromContext() -> Double {
        let hour = Calendar.current.component(.hour, from: Date())
        let isDaytime = hour >= 7 && hour < 19
        let baseLux = isDaytime ? 200.0 : 10.0
        let noise = Double.random(in: -20...20)
        return max(0, baseLux + noise)
    }
    
    private func handleSunlightDetected() {
        lastSunlightDate = Date()
        UserDefaults.standard.set(Date(), forKey: kLastSunlightDate)
        darknessStartTime = nil
        timeInDarkness = 0
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
    
    // MARK: - StoreKit
    
    func payTax() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        brightnessLimit = 1.0
        setDisplayBrightness(1.0)
        totalTaxPaid += Double(truncating: taxAmount as NSNumber)
        UserDefaults.standard.set(totalTaxPaid, forKey: kTotalTaxPaid)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600) { [weak self] in
            self?.updateTaxStatus()
        }
    }
    
    func purchasePremium() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        hasPremiumSubscription = true
        UserDefaults.standard.set(true, forKey: kHasPremium)
        brightnessLimit = 1.0
        setDisplayBrightness(1.0)
        taxStatus = .premium
    }
    
    // MARK: - Formatting
    
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
        let hours = Int(timeUntilTax) / 3600
        let minutes = Int(timeUntilTax) % 3600 / 60
        return "\(hours)h \(minutes)m"
    }
    
    var progressToTax: Double {
        min(timeInDarkness / taxThreshold, 1.0)
    }
}
