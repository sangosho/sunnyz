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
    
    static let shared = SunlightTaxManager()
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
    @Published var timeAcceleration: Double = 1.0
    
    // MARK: - Computed Settings
    
    var debugModeEnabled: Bool {
        settings.debugModeEnabled
    }
    
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
        
        var color: String {
            switch self {
            case .exempt: return "#4CAF50"
            case .warning: return "#FF9800"
            case .taxed: return "#F44336"
            case .premium: return "#9C27B0"
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
    private var taxReliefWorkItem: DispatchWorkItem?
    
    private let settings = SettingsManager.shared
    private let luxSensor = LuxSensorManager.shared
    
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
        // Release IOKit display service (nonisolated, safe for deinit)
        if displayService != 0 {
            IOObjectRelease(displayService)
        }
    }

    private func releaseDisplayService() {
        if displayService != 0 {
            IOObjectRelease(displayService)
            displayService = 0
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
        let interval = debugModeEnabled ? (5.0 / timeAcceleration) : 5.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSunlightStatus()
            }
        }
        updateSunlightStatus()
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        taxReliefWorkItem?.cancel()
        taxReliefWorkItem = nil
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
        taxReliefWorkItem?.cancel()
        taxReliefWorkItem = nil
        
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
            0,
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
            0,
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
    
    private func scheduleTaxReliefExpiry() {
        // Cancel any existing tax relief timer
        taxReliefWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.updateTaxStatus()
        }
        taxReliefWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3600, execute: workItem)
    }
    
    /// In debug mode, simulates a payment without touching StoreKit.
    /// Shows a convincing "processing" animation but no real charge.
    ///
    /// DANGEROUS: If `dangerouslySkipPermission` is enabled in SettingsManager,
    /// this would process REAL Apple Pay transactions. For now, we still simulate
    /// because implementing actual StoreKit IAP requires:
    /// 1. App Store Connect setup
    /// 2. Consumable IAP product configuration
    /// 3. StoreKit2 integration with Transaction.updates
    /// 4. Sandbox testing
    /// ...and you probably don't actually want to charge people for a satirical app 😅
    func payTax() async throws {
        let dangerouslyEnabled = SettingsManager.shared.dangerouslySkipPermission

        if debugModeEnabled || !dangerouslyEnabled {
            // Simulate a fake payment — looks real to the user, no charge
            let processingDelay = debugModeEnabled ? 1_500_000_000 : 500_000_000
            try await Task.sleep(nanoseconds: UInt64(processingDelay))
            brightnessLimit = 1.0
            setDisplayBrightness(1.0)
            totalTaxPaid += Double(truncating: taxAmount as NSNumber)
            UserDefaults.standard.set(totalTaxPaid, forKey: kTotalTaxPaid)
            AchievementManager.shared.handleTaxPayment()
            // Tax relief expires after 1 hour (same as real)
            scheduleTaxReliefExpiry()
            return
        }

        // TODO: Implement real Apple Pay via StoreKit2 when dangerouslySkipPermission is enabled
        // This would require:
        // - import StoreKit
        // - Product.purchase() calls
        // - Transaction.updates listener
        // - Receipt validation
        // For now, even with the toggle enabled, we still simulate because implementing
        // real payments for a satirical app is... a choice.
        print("[SunnyZ] ⚠️ Real payments enabled but not implemented. Still simulating.")
        try await Task.sleep(nanoseconds: 2_000_000_000) // Longer delay to feel "real"
        brightnessLimit = 1.0
        setDisplayBrightness(1.0)
        totalTaxPaid += Double(truncating: taxAmount as NSNumber)
        UserDefaults.standard.set(totalTaxPaid, forKey: kTotalTaxPaid)
        AchievementManager.shared.handleTaxPayment()
        scheduleTaxReliefExpiry()
    }

    /// In debug mode, simulates premium purchase without touching StoreKit.
    func purchasePremium() async throws {
        // Guard: already premium
        guard !hasPremiumSubscription else {
            print("[SunnyZ] Already have premium subscription")
            return
        }

        if debugModeEnabled {
            // Simulate a fake premium purchase
            try await Task.sleep(nanoseconds: 2_000_000_000) // fake "processing" delay
            hasPremiumSubscription = true
            UserDefaults.standard.set(true, forKey: kHasPremium)
            brightnessLimit = 1.0
            setDisplayBrightness(1.0)
            taxStatus = .premium
            return
        }

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

    // MARK: - Sleep/Wake Adjustments

    /// Adjusts darkness tracking to account for system sleep time
    /// Since user couldn't get sunlight while sleeping, we subtract sleep time
    func adjustForSleepDuration(_ sleepDuration: TimeInterval) {
        guard let startTime = darknessStartTime else { return }

        // Adjust the darkness start time forward by sleep duration
        // This prevents counting sleep time toward tax
        if let newStartTime = Calendar.current.date(byAdding: .second, value: Int(sleepDuration), to: startTime) {
            darknessStartTime = newStartTime
            UserDefaults.standard.set(newStartTime, forKey: kDarknessStartTime)

            // Recalculate time in darkness
            timeInDarkness = Date().timeIntervalSince(newStartTime)

            print("[SunnyZ] Adjusted darkness time for sleep: -\(Int(sleepDuration/60)) min")
            updateTaxStatus()
        }
    }

    // MARK: - Display Connection Management

    /// Refreshes the display service connection (called after display configuration changes)
    func refreshDisplayConnection() {
        releaseDisplayService()
        setupDisplayConnection()
        print("[SunnyZ] Display connection refreshed")
    }
    
    // MARK: - Debug
    
    /// Forces the tax status to a specific value (debug only)
    func forceTaxStatus(_ status: TaxStatus) {
        #if DEBUG
        guard debugModeEnabled else { return }
        taxStatus = status
        if status == .taxed {
            brightnessLimit = taxedBrightnessLimit
        } else {
            brightnessLimit = 1.0
        }
        #endif
    }
    
    /// Forces the time in darkness to a specific duration (debug only)
    func forceTimeInDarkness(_ duration: TimeInterval) {
        #if DEBUG
        guard debugModeEnabled else { return }
        timeInDarkness = duration
        darknessStartTime = Date().addingTimeInterval(-duration)
        UserDefaults.standard.set(darknessStartTime, forKey: kDarknessStartTime)
        updateTaxStatus()
        #endif
    }
    
    /// Resets the darkness timer (debug only)
    func resetDarknessTimer() {
        #if DEBUG
        guard debugModeEnabled else { return }
        darknessStartTime = nil
        timeInDarkness = 0
        UserDefaults.standard.removeObject(forKey: kDarknessStartTime)
        brightnessLimit = 1.0
        updateTaxStatus()
        #endif
    }
    
    /// Sets the time acceleration multiplier (debug only)
    func setTimeAcceleration(_ multiplier: Double) {
        #if DEBUG
        guard debugModeEnabled else { return }
        timeAcceleration = max(1.0, multiplier)
        // Restart timer with new interval
        stopMonitoring()
        startMonitoring()
        #endif
    }
}
