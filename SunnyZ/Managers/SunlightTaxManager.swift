//
//  SunlightTaxManager.swift
//  SunnyZ
//
//  Sunlight Tax - The premium subscription for going outside
//

import Foundation
import UIKit
import CoreMotion
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
    @Published var brightnessLimit: CGFloat = 1.0
    @Published var hasPremiumSubscription: Bool = false
    @Published var totalTaxPaid: Double = 0
    @Published var lastSunlightDate: Date?
    
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
            case .taxed: return "#F44336"
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
    let taxThreshold: TimeInterval = 4 * 60 * 60  // 4 hours
    
    /// Warning threshold (3.5 hours)
    let warningThreshold: TimeInterval = 3.5 * 60 * 60
    
    /// Brightness limit when taxed (50%)
    let taxedBrightnessLimit: CGFloat = 0.5
    
    /// Tax amount per unlock
    let taxAmount: Decimal = 0.99
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private var cancellables = Set<AnyCancellable>()
    private var darknessStartTime: Date?
    private var timer: Timer?
    private var brightnessObserver: NSObjectProtocol?
    
    // UserDefaults keys
    private let kTotalTaxPaid = "sunlightTax.totalPaid"
    private let kLastSunlightDate = "sunlightTax.lastSunlight"
    private let kHasPremium = "sunlightTax.hasPremium"
    
    // MARK: - Initialization
    
    init() {
        loadSavedState()
        setupBrightnessObserver()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
        if let observer = brightnessObserver {
            NotificationCenter.default.removeObserver(observer)
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
    
    private func setupBrightnessObserver() {
        // Monitor system brightness changes
        brightnessObserver = NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.enforceBrightnessLimit()
        }
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        // Use ambient light sensor via CMMotionManager (indirect approach)
        // Note: Direct ALS access is private API, so we use a combination of
        // brightness detection and motion activity
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateSunlightStatus()
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
        // Estimate ambient light based on screen brightness and device orientation
        // This is a heuristic approach since direct ALS is private
        
        let screenBrightness = Double(UIScreen.main.brightness)
        
        // If user keeps brightness high, they might be compensating for dark environment
        // If brightness is low, they might be in a dark room
        
        // Use a simulated lux estimate based on various factors
        let estimatedLux = estimateAmbientLux(screenBrightness: screenBrightness)
        currentLux = estimatedLux
        
        // Check if we're in sunlight
        if estimatedLux >= sunlightThreshold {
            // Sunlight detected!
            handleSunlightDetected()
        } else if estimatedLux <= darknessThreshold {
            // Darkness detected
            handleDarknessDetected()
        }
        
        // Update tax status
        updateTaxStatus()
        
        // Enforce brightness limits
        enforceBrightnessLimit()
    }
    
    private func estimateAmbientLux(screenBrightness: Double) -> Double {
        // Heuristic: If screen brightness is maxed out, user might be in bright environment
        // If screen brightness is low, user might be in dark environment
        // This is a playful approximation for the hackathon
        
        let autoBrightnessEnabled = UIScreen.main.isBrightnessManuallySet == false
        
        // Base estimate on current brightness setting
        var estimatedLux = screenBrightness * 500  // 0-1 -> 0-500 lux
        
        // Adjust for auto-brightness behavior
        if autoBrightnessEnabled {
            // If auto-brightness is on, the system has already adjusted
            // Higher system brightness = brighter environment
            estimatedLux = screenBrightness * 1000
        }
        
        // Add some "randomness" to simulate sensor noise
        let noise = Double.random(in: -20...20)
        return max(0, estimatedLux + noise)
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
    
    private func enforceBrightnessLimit() {
        guard taxStatus == .taxed else { return }
        
        let currentBrightness = UIScreen.main.brightness
        if currentBrightness > brightnessLimit {
            UIScreen.main.brightness = brightnessLimit
        }
    }
    
    // MARK: - StoreKit Integration
    
    /// Pay the sunlight tax to unlock brightness temporarily
    func payTax() async throws {
        // For hackathon: simulate the purchase
        // In production, use StoreKit 2:
        // let product = try await Product.products(for: ["sunlight.tax.unlock"])
        // let result = try await product.purchase()
        
        // Simulate purchase delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Unlock brightness for 1 hour
        brightnessLimit = 1.0
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

// MARK: - UIScreen Extension

extension UIScreen {
    var isBrightnessManuallySet: Bool {
        // Check if auto-brightness is disabled
        // This is a heuristic - iOS doesn't expose this directly
        return false
    }
}
