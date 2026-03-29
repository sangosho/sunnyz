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
    @Published var luxAccuracy: LuxAccuracy = .estimated
    
    // MARK: - Computed Settings
    
    var taxThreshold: TimeInterval {
        settings.taxThresholdInterval
    }
    
    var warningThreshold: TimeInterval {
        settings.warningThresholdInterval
    }
    
    var sunlightThreshold: Double {
        settings.sunlightLuxThreshold
    }
    
    var darknessThreshold: Double {
        settings.darknessLuxThreshold
    }
    
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
    
    let taxedBrightnessLimit: Double = 0.5
    let taxAmount: Decimal = 0.99
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var darknessStartTime: Date?
    private var timer: Timer?
    private var displayService: io_object_t = 0
    
    private let settings = SettingsManager.shared
    private let luxSensor = LuxSensorManager()
    
    private let kTotalTaxPaid = "sunlightTax.totalPaid"
    private let kLastSunlightDate = "sunlightTax.lastSunlight"
    private let kHasPremium = "sunlightTax.hasPremium"
    private let kTimeInDarkness = "sunlightTax.timeInDarkness"
    private let kDarknessStartTime = "sunlightTax.darknessStartTime"
    
    // MARK: - Initialization
    
    init() {
        loadSavedState()
        setupDisplayConnection()
        startMonitoring()
        setupSubscriptions()
    }
    
    deinit {
        stopMonitoring()
        saveState()
        if displayService != 0 {
            IOObjectRelease(displayService)
        }
    }
    
    private func setupSubscriptions() {
        // Listen for tax threshold changes
        NotificationCenter.default.publisher(for: .taxThresholdChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTaxStatus()
            }
            .store(in: &cancellables)
        
        // Listen for stats reset
        NotificationCenter.default.publisher(for: .statsReset)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleStatsReset()
            }
            .store(in: &cancellables)
    }
    
    private func loadSavedState() {
        totalTaxPaid = UserDefaults.standard.double(forKey: kTotalTaxPaid)
        hasPremiumSubscription = UserDefaults.standard.bool(forKey: kHasPremium)
        
        if let date = UserDefaults.standard.object(forKey: kLastSunlightDate) as? Date {
            lastSunlightDate = date
        }
        
        // Restore darkness tracking if app was quit while in dark
        if let savedStartTime = UserDefaults.standard.object(forKey: kDarknessStartTime) as? Date {
            // Only restore if it was recent (within last 24 hours)
            if Date().timeIntervalSince(savedStartTime) < 24 * 3600 {
                darknessStartTime = savedStartTime
                timeInDarkness = Date().timeIntervalSince(savedStartTime)
            }
        }
    }
    
    private func saveState() {
        UserDefaults.standard.set(totalTaxPaid, forKey: kTotalTaxPaid)
        UserDefaults.standard.set(hasPremiumSubscription, forKey: kHasPremium)
        UserDefaults.standard.set(timeInDarkness, forKey: kTimeInDarkness)
        
        if let startTime = darknessStartTime {
            UserDefaults.standard.set(startTime, forKey: kDarknessStartTime)
        } else {
            UserDefaults.standard.removeObject(forKey: kDarknessStartTime)
        }
        
        if let sunlightDate = lastSunlightDate {
            UserDefaults.standard.set(sunlightDate, forKey: kLastSunlightDate)
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
        saveState()
    }
    
    private func updateSunlightStatus() {
        // Use LuxSensorManager for readings
        let lux = luxSensor.readLux()
        currentLux = lux
        luxAccuracy = luxSensor.accuracy
        currentDisplayBrightness = getDisplayBrightness()
        
        if lux >= sunlightThreshold {
            handleSunlightDetected()
        } else if lux <= darknessThreshold {
            handleDarknessDetected()
        }
        
        updateTaxStatus()
        enforceBrightnessLimit()
    }
    
    private func handleSunlightDetected() {
        // Only reset if we're actually coming from darkness
        if darknessStartTime != nil {
            lastSunlightDate = Date()
            UserDefaults.standard.set(Date(), forKey: kLastSunlightDate)
            
            // Reset notification state when going outside
            NotificationManager.shared.resetNotificationState()
            
            // Post sunlight detected notification for snark manager
            NotificationCenter.default.post(name: .sunlightDetected, object: nil)
            
            darknessStartTime = nil
            timeInDarkness = 0
            brightnessLimit = 1.0
            
            // Clear saved darkness start time
            UserDefaults.standard.removeObject(forKey: kDarknessStartTime)
        }
    }
    
    private func handleDarknessDetected() {
        if darknessStartTime == nil {
            darknessStartTime = Date()
            UserDefaults.standard.set(Date(), forKey: kDarknessStartTime)
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
    
    private func handleStatsReset() {
        totalTaxPaid = 0
        hasPremiumSubscription = false
        lastSunlightDate = nil
        darknessStartTime = nil
        timeInDarkness = 0
        brightnessLimit = 1.0
        
        UserDefaults.standard.removeObject(forKey: kTotalTaxPaid)
        UserDefaults.standard.removeObject(forKey: kHasPremium)
        UserDefaults.standard.removeObject(forKey: kLastSunlightDate)
        UserDefaults.standard.removeObject(forKey: kDarknessStartTime)
        UserDefaults.standard.removeObject(forKey: kTimeInDarkness)
        
        updateTaxStatus()
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
    
    // MARK: - StoreKit
    
    func payTax() async throws {
        try await Task.sleep(nanoseconds: 500_000_000)
        brightnessLimit = 1.0
        setDisplayBrightness(1.0)
        totalTaxPaid += Double(truncating: taxAmount as NSNumber)
        UserDefaults.standard.set(totalTaxPaid, forKey: kTotalTaxPaid)

        // Track tax payment for achievements
        AchievementManager.shared.handleTaxPayment()

        // Temporary tax relief - reset after 1 hour
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
    
    var formattedTaxThreshold: String {
        settings.formattedTaxThreshold
    }
    
    // MARK: - Settings Access
    
    var settingsManager: SettingsManager {
        settings
    }
    
    var luxSensorManager: LuxSensorManager {
        luxSensor
    }
}
