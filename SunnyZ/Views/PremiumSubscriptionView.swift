//
//  PremiumSubscriptionView.swift
//  SunnyZ
//
//  Premium subscription window
//

import SwiftUI

struct PremiumSubscriptionView: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @State private var isProcessing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 12) {
                    Text("👑")
                        .font(.system(size: 64))
                    
                    Text("Premium Cave Dweller")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    Text("The ultimate late-stage capitalism experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Pricing
                VStack(spacing: 4) {
                    Text("$4.99")
                        .font(.system(size: 40, weight: .bold))
                    Text("per month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.purple.opacity(0.3), .pink.opacity(0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                
                // Features
                VStack(alignment: .leading, spacing: 12) {
                    Text("Premium Features")
                        .font(.headline)
                    
                    PremiumFeatureRow(
                        icon: "💰",
                        title: "No Sunlight Tax",
                        description: "Never pay the $0.99 tax again"
                    )
                    
                    PremiumFeatureRow(
                        icon: "☀️",
                        title: "Unlimited Brightness",
                        description: "Full display brightness 24/7"
                    )
                    
                    PremiumFeatureRow(
                        icon: "📊",
                        title: "Cave Stats",
                        description: "Detailed indoor time analytics"
                    )
                    
                    PremiumFeatureRow(
                        icon: "🏆",
                        title: "Cave Dweller Badge",
                        description: "Show off your commitment"
                    )
                    
                    PremiumFeatureRow(
                        icon: "💻",
                        title: "Developer Mode",
                        description: "Optimized for coding marathons"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Testimonials
                VStack(alignment: .leading, spacing: 10) {
                    Text("What Users Say")
                        .font(.headline)
                    
                    TestimonialCard(
                        quote: "I haven't seen the sun in 3 weeks. Worth every penny!",
                        author: "@CaveCoder99"
                    )
                    
                    TestimonialCard(
                        quote: "Finally, a subscription that understands me.",
                        author: "@BasementDev"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Subscribe button
                Button(action: subscribe) {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Subscribe $4.99/month")
                                .fontWeight(.semibold)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isProcessing ? Color.gray : Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
                .disabled(isProcessing)
                .buttonStyle(.plain)
                
                Text("Auto-renews. Cancel anytime. No refunds for sunlight exposure.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .frame(width: 380, height: 600)
    }
    
    private func subscribe() {
        isProcessing = true
        
        Task {
            try? await taxManager.purchasePremium()
            
            await MainActor.run {
                isProcessing = false
                dismissWindow()
                
                let alert = NSAlert()
                alert.messageText = "Welcome to Premium! 👑"
                alert.informativeText = "You're now a certified cave dweller."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Awesome")
                alert.runModal()
            }
        }
    }
    
    private func dismissWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct TestimonialCard: View {
    let quote: String
    let author: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\"\(quote)\"")
                .font(.caption)
                .italic()
            Text("— \(author)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.5))
        .cornerRadius(6)
    }
}

struct PremiumSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumSubscriptionView(taxManager: SunlightTaxManager())
    }
}
