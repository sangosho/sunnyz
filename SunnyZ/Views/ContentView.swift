//
//  ContentView.swift
//  SunnyZ
//
//  Main UI for the Sunlight Tax experience (macOS)
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var taxManager = SunlightTaxManager.shared
    @State private var showingPaywall = false
    @State private var showingPremium = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background based on tax status
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status Header
                        statusHeader
                        
                        // Lux Meter
                        luxMeter
                        
                        // Darkness Timer
                        darknessTimer
                        
                        // Tax Status Card
                        taxStatusCard
                        
                        // Action Buttons
                        actionButtons
                        
                        // Stats
                        statsSection
                        
                        // Educational Content
                        educationalCard
                    }
                    .padding()
                }
            }
            .navigationTitle("☀️ SunnyZ")
            .sheet(isPresented: $showingPaywall) {
                TaxPaywallView(taxManager: taxManager)
            }
            .sheet(isPresented: $showingPremium) {
                PremiumSubscriptionView(taxManager: taxManager)
            }
            .frame(minWidth: 600, minHeight: 700)
        }
        .navigationViewStyle(.automatic)
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        switch taxManager.taxStatus {
        case .exempt:
            return LinearGradient(
                colors: [Color(hex: "#FFF9C4"), Color(hex: "#FFECB3")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .warning:
            return LinearGradient(
                colors: [Color(hex: "#FFE0B2"), Color(hex: "#FFCC80")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .taxed:
            return LinearGradient(
                colors: [Color(hex: "#FFCDD2"), Color(hex: "#EF9A9A")],
                startPoint: .top,
                endPoint: .bottom
            )
        case .premium:
            return LinearGradient(
                colors: [Color(hex: "#E1BEE7"), Color(hex: "#CE93D8")],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        VStack(spacing: 8) {
            Text(taxManager.taxStatus.description)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(Color(hex: taxManager.taxStatus.color))
            
            if taxManager.taxStatus == .taxed {
                Text("💸 Your cave-dwelling behavior has been taxed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else if taxManager.taxStatus == .warning {
                Text("⚠️ Tax incoming in \(taxManager.formattedTimeUntilTax)")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }
    
    // MARK: - Lux Meter
    
    private var luxMeter: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🌡️ Ambient Light")
                    .font(.headline)
                Spacer()
                Text("\(Int(taxManager.currentLux)) lux")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            
            // Lux progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 24)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(luxGradient)
                        .frame(width: luxBarWidth(in: geo), height: 24)
                    
                    // Threshold markers
                    thresholdMarker(at: 0.1, in: geo, label: "🌑")
                    thresholdMarker(at: 0.2, in: geo, label: "🏠")
                    thresholdMarker(at: 1.0, in: geo, label: "☀️")
                }
            }
            .frame(height: 24)
            
            HStack {
                Text("Darkness")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Sunlight")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }
    
    private var luxGradient: LinearGradient {
        LinearGradient(
            colors: [Color.purple, Color.blue, Color.yellow, Color.orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func luxBarWidth(in geometry: GeometryProxy) -> CGFloat {
        let maxLux: Double = 500
        let percentage = min(taxManager.currentLux / maxLux, 1.0)
        return geometry.size.width * CGFloat(percentage)
    }
    
    private func thresholdMarker(at position: Double, in geometry: GeometryProxy, label: String) -> some View {
        HStack {
            Spacer()
                .frame(width: geometry.size.width * CGFloat(position))
            Text(label)
                .font(.caption)
            Spacer()
        }
    }
    
    // MARK: - Darkness Timer
    
    private var darknessTimer: some View {
        VStack(spacing: 12) {
            HStack {
                Text("🦇 Cave Dweller Timer")
                    .font(.headline)
                Spacer()
            }
            
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(taxManager.formattedTimeInDarkness)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(timerColor)
                Text("in darkness")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if taxManager.timeInDarkness > 0 {
                ProgressView(value: min(taxManager.timeInDarkness / taxManager.taxThreshold, 1.0))
                    .tint(timerColor)
                    .scaleEffect(y: 2)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }
    
    private var timerColor: Color {
        switch taxManager.taxStatus {
        case .exempt: return .green
        case .warning: return .orange
        case .taxed: return .red
        case .premium: return .purple
        }
    }
    
    // MARK: - Tax Status Card
    
    private var taxStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("💰 Tax Status")
                    .font(.headline)
                Spacer()
                StatusBadge(status: taxManager.taxStatus)
            }
            
            Divider()
            
            if taxManager.taxStatus == .taxed {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your display brightness is currently limited to 50%")
                        .font(.subheadline)
                    
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Go outside or pay the tax to unlock full brightness")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else if taxManager.taxStatus == .premium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.purple)
                    Text("Premium member - unlimited cave dwelling privileges")
                        .font(.subheadline)
                }
            } else {
                Text("You're currently tax-exempt. Enjoy the sunlight! ☀️")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if taxManager.taxStatus == .taxed {
                Button(action: { showingPaywall = true }) {
                    HStack {
                        Image(systemName: "creditcard.fill")
                        Text("Pay $0.99 Tax Unlock")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
            
            if !taxManager.hasPremiumSubscription {
                Button(action: { showingPremium = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Upgrade to Premium - $4.99/mo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Stats Section
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📊 Your Cave Stats")
                .font(.headline)
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Tax Paid",
                    value: taxManager.formattedTotalTax,
                    icon: "💸"
                )
                
                if let lastSunlight = taxManager.lastSunlightDate {
                    StatCard(
                        title: "Last Sunlight",
                        value: timeAgo(from: lastSunlight),
                        icon: "☀️"
                    )
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Educational Card
    
    private var educationalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🧠 Why This Exists")
                .font(.headline)
            
            Text("Late-stage capitalism has gamified everything. Why not your relationship with the sun? The outdoors is now a premium subscription tier. Touch grass™ - now with in-app purchases.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack {
                Spacer()
                Text("#TouchGrass #SunlightTax")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white.opacity(0.8))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let status: SunlightTaxManager.TaxStatus
    
    var body: some View {
        Text(status == .taxed ? "TAXED" : status == .premium ? "PREMIUM" : "EXEMPT")
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: status.color).opacity(0.2))
            .foregroundColor(Color(hex: status.color))
            .cornerRadius(8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(icon)
                .font(.title2)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
