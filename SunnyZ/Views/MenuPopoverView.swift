//
//  MenuPopoverView.swift
//  SunnyZ
//
//  Popover menu content with lux accuracy indicator
//

import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @ObservedObject private var snarkManager = SnarkManager.shared
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var showingPaywall = false
    @State private var showingPremium = false
    @State private var showingSettings = false
    @State private var showingAchievementsCelebration = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with status
                headerSection

                Divider()

                // Stats
                statsSection

                Divider()

                // Progress bar
                progressSection

                Divider()

                // Snark indicator
                snarkSection

                Divider()

                // Lux accuracy indicator
                luxAccuracySection

                Divider()

                // Achievement indicator
                achievementSection

                Divider()

                // Actions
                actionsSection

                Spacer()

                // Footer
                footerSection
            }
            .padding(.vertical, 12)
            .frame(width: 320)

            // Confetti celebration overlay
            if achievementManager.showConfetti {
                confettiCelebration
            }
        }
        .onAppear {
            checkAchievementsOnAppear()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text(taxManager.taxStatus.icon)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusSubtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Settings button
                Button(action: showSettings) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.1))
        }
    }
    
    private var statusTitle: String {
        switch taxManager.taxStatus {
        case .exempt: return "Tax Exempt"
        case .warning: return "Warning"
        case .taxed: return "TAX DUE"
        case .premium: return "Premium"
        }
    }
    
    private var statusSubtitle: String {
        switch taxManager.taxStatus {
        case .exempt:
            return "Enjoy the sunlight!"
        case .warning:
            return "Tax in \(taxManager.formattedTimeUntilTax)"
        case .taxed:
            return "Brightness limited to 50%"
        case .premium:
            return "Unlimited cave dwelling"
        }
    }
    
    private var statusColor: Color {
        switch taxManager.taxStatus {
        case .exempt: return .green
        case .warning: return .orange
        case .taxed: return .red
        case .premium: return .purple
        }
    }
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            HStack {
                StatItem(
                    icon: "🌡️",
                    value: "\(Int(taxManager.currentLux))",
                    label: "lux"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "🦇",
                    value: taxManager.formattedTimeInDarkness,
                    label: "in dark"
                )
                
                Divider()
                    .frame(height: 40)
                
                StatItem(
                    icon: "💸",
                    value: taxManager.formattedTotalTax,
                    label: "tax paid"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Cave Dweller Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(taxManager.progressToTax * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressGradient)
                        .frame(width: geo.size.width * CGFloat(taxManager.progressToTax), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var snarkSection: some View {
        HStack(spacing: 8) {
            Text(snarkManager.snarkLevel.emoji)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Snark Level: \(snarkManager.snarkLevel.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if snarkManager.remindersEnabled && snarkManager.reminderInterval != .off {
                        Circle()
                            .fill(Color.purple)
                            .frame(width: 6, height: 6)
                    }
                }
                
                if snarkManager.remindersEnabled && snarkManager.reminderInterval != .off {
                    Text(snarkManager.nextReminderDescription)
                        .font(.caption2)
                        .foregroundColor(.purple)
                } else {
                    Text("Reminders off")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Manual remind button
            if snarkManager.remindersEnabled {
                Button(action: sendManualReminder) {
                    Image(systemName: "bell.fill")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .help("Remind me now")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.05))
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.green, .yellow, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var luxAccuracySection: some View {
        HStack(spacing: 8) {
            Image(systemName: luxAccuracyIcon)
                .foregroundColor(luxAccuracyColor)
                .font(.caption)
            
            Text("Light sensor: \(taxManager.luxAccuracy.displayText.lowercased())")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if taxManager.luxAccuracy != .accurate {
                Text("Using time estimate")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
    
    private var luxAccuracyIcon: String {
        switch taxManager.luxAccuracy {
        case .accurate: return "checkmark.circle.fill"
        case .estimated: return "exclamationmark.triangle.fill"
        case .unavailable: return "xmark.circle.fill"
        }
    }
    
    private var luxAccuracyColor: Color {
        switch taxManager.luxAccuracy {
        case .accurate: return .green
        case .estimated: return .orange
        case .unavailable: return .red
        }
    }

    private var achievementSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "trophy.fill")
                .foregroundColor(.yellow)
                .font(.caption)

            Text("Achievements: \(achievementManager.totalUnlocked)/\(achievementManager.achievements.count)")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Show recently unlocked badge
            if !achievementManager.recentlyUnlocked.isEmpty {
                let latest = achievementManager.recentlyUnlocked.last
                Text(latest?.icon ?? "")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.yellow.opacity(0.05))
        .onTapGesture {
            // Open achievements
            NotificationCenter.default.post(name: .showAchievements, object: nil)
        }
    }

    private var confettiCelebration: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 64))

                Text("You Touched Grass!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("We're so proud of you.")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .shadow(radius: 20)

            ConfettiView(isActive: $achievementManager.showConfetti)
        }
        .allowsHitTesting(false)
    }

    private func checkAchievementsOnAppear() {
        let taxPaymentCount = UserDefaults.standard.integer(forKey: "sunlightTax.taxPaymentCount")

        achievementManager.checkAchievements(
            timeInDarkness: taxManager.timeInDarkness,
            totalTaxPaid: taxManager.totalTaxPaid,
            taxPaymentCount: taxPaymentCount,
            lastSunlightDate: taxManager.lastSunlightDate,
            isTaxed: taxManager.taxStatus == .taxed
        )
    }

    private var actionsSection: some View {
        VStack(spacing: 8) {
            if taxManager.taxStatus == .taxed {
                Button(action: payTax) {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                        Text("Pay $0.99 Tax")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
            
            if !taxManager.hasPremiumSubscription {
                Button(action: showPremium) {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Go Premium - $4.99/mo")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                .controlSize(.large)
            }
            
            Button(action: quit) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit SunnyZ")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var footerSection: some View {
        Text("Late-stage capitalism meets touch grass™")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.bottom, 8)
    }
    
    private func payTax() {
        Task { @MainActor in
            do {
                try await taxManager.payTax()

                let alert = NSAlert()
                alert.messageText = "Tax Paid! 💸"
                alert.informativeText = "Brightness restored for 1 hour. Your cave-dwelling privileges have been temporarily extended."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                // Optionally handle error
            }
        }
    }
    
    private func showPremium() {
        // Close popover and open premium window
        NSApp.sendAction(Selector(("performClose:")), to: nil, from: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .showPremium, object: nil)
        }
    }
    
    private func showSettings() {
        // Close popover and open settings window
        NSApp.sendAction(Selector(("performClose:")), to: nil, from: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .showSettings, object: nil)
        }
    }
    
    private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func sendManualReminder() {
        snarkManager.sendTestReminder()
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title3)
            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension Notification.Name {
    static let showPremium = Notification.Name("showPremium")
    static let showSettings = Notification.Name("showSettings")
    static let showAchievements = Notification.Name("showAchievements")
}

struct MenuPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        MenuPopoverView(taxManager: SunlightTaxManager.shared)
    }
}
