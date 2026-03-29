//
//  MenuPopoverView.swift
//  SunnyZ
//
//  Popover menu content
//

import SwiftUI

struct MenuPopoverView: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @State private var showingPaywall = false
    @State private var showingPremium = false
    
    var body: some View {
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
            
            // Actions
            actionsSection
            
            Spacer()
            
            // Footer
            footerSection
        }
        .padding(.vertical, 12)
        .frame(width: 320)
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
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.green, .yellow, .orange, .red],
            startPoint: .leading,
            endPoint: .trailing
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
        Task {
            try? await taxManager.payTax()
        }
        
        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "Tax Paid! 💸"
        alert.informativeText = "Brightness restored for 1 hour. Your cave-dwelling privileges have been temporarily extended."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showPremium() {
        // Close popover and open premium window
        NSApp.sendAction(#selector(NSPopover.performClose(_)), to: nil, from: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NotificationCenter.default.post(name: .showPremium, object: nil)
        }
    }
    
    private func quit() {
        NSApplication.shared.terminate(nil)
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
}

struct MenuPopoverView_Previews: PreviewProvider {
    static var previews: some View {
        MenuPopoverView(taxManager: SunlightTaxManager())
    }
}
