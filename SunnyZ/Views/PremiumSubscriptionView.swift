//
//  PremiumSubscriptionView.swift
//  SunnyZ
//
//  Premium subscription for unlimited cave dwelling (macOS)
//

import SwiftUI

struct PremiumSubscriptionView: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Crown header
                VStack(spacing: 16) {
                    Text("👑")
                        .font(.system(size: 80))
                    
                    Text("Premium Cave Dweller")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                    
                    Text("The ultimate late-stage capitalism experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Pricing
                VStack(spacing: 8) {
                    Text("$4.99")
                        .font(.system(size: 48, weight: .bold))
                    Text("per month")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                
                // Features
                VStack(alignment: .leading, spacing: 16) {
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
                        description: "Full display brightness 24/7, even in caves"
                    )
                    
                    PremiumFeatureRow(
                        icon: "📊",
                        title: "Cave Stats",
                        description: "Detailed analytics on your indoor time"
                    )
                    
                    PremiumFeatureRow(
                        icon: "🏆",
                        title: "Cave Dweller Badge",
                        description: "Show off your commitment to the indoors"
                    )
                    
                    PremiumFeatureRow(
                        icon: "💻",
                        title: "Developer Mode",
                        description: "Optimized for marathon coding sessions"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                
                // Testimonials
                VStack(alignment: .leading, spacing: 12) {
                    Text("What Premium Users Say")
                        .font(.headline)
                    
                    TestimonialCard(
                        quote: "I haven't seen the sun in 3 weeks. Worth every penny!",
                        author: "@CaveCoder99"
                    )
                    
                    TestimonialCard(
                        quote: "Finally, a subscription that understands my lifestyle.",
                        author: "@BasementDeveloper"
                    )
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                
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
                .cornerRadius(12)
                .disabled(isProcessing)
                .buttonStyle(.plain)
                
                // Disclaimer
                Text("Subscription auto-renews. Cancel anytime. No refunds for sunlight exposure.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .frame(width: 500, height: 700)
        .overlay {
            if showSuccess {
                PremiumSuccessOverlay()
            }
        }
    }
    
    private func subscribe() {
        isProcessing = true
        
        Task {
            try? await taxManager.purchasePremium()
            
            await MainActor.run {
                isProcessing = false
                showSuccess = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
    }
}

struct PremiumFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("\"\(quote)\"")
                .font(.subheadline)
                .italic()
            Text("— \(author)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
    }
}

struct PremiumSuccessOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
            
            VStack(spacing: 16) {
                Text("👑")
                    .font(.system(size: 60))
                Text("Welcome to Premium!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("You're now a certified cave dweller")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .background(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(16)
        }
    }
}

struct PremiumSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumSubscriptionView(taxManager: SunlightTaxManager())
    }
}
