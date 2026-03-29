//
//  TaxPaywallView.swift
//  SunnyZ
//
//  The paywall for paying the sunlight tax
//

import SwiftUI

struct TaxPaywallView: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#FFCDD2").opacity(0.3).ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Text("💸")
                            .font(.system(size: 80))
                        
                        Text("SUNLIGHT TAX DUE")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("Your cave-dwelling behavior has consequences")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Tax breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tax Breakdown")
                            .font(.headline)
                        
                        HStack {
                            Text("Time in Darkness")
                            Spacer()
                            Text(taxManager.formattedTimeInDarkness)
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Brightness Penalty")
                            Spacer()
                            Text("-50%")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Tax Amount")
                                .font(.headline)
                            Spacer()
                            Text("$0.99")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    
                    // Unlock benefits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What You Get")
                            .font(.headline)
                        
                        BenefitRow(icon: "☀️", text: "Full brightness restored (1 hour)")
                        BenefitRow(icon: "🎮", text: "Continue gaming in the dark")
                        BenefitRow(icon: "😴", text: "Maintain your cave lifestyle")
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(16)
                    
                    Spacer()
                    
                    // Pay button
                    Button(action: payTax) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text("Pay $0.99 Tax")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isProcessing ? Color.gray : Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isProcessing)
                    
                    // Alternative
                    Button("Go Outside Instead (Free)") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Close") { dismiss() })
            .overlay {
                if showSuccess {
                    SuccessOverlay()
                }
            }
        }
    }
    
    private func payTax() {
        isProcessing = true
        
        Task {
            try? await taxManager.payTax()
            
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

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct SuccessOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            
            VStack(spacing: 16) {
                Text("✅")
                    .font(.system(size: 60))
                Text("Tax Paid!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Brightness restored for 1 hour")
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .background(Color.green)
            .cornerRadius(16)
        }
    }
}

struct TaxPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        TaxPaywallView(taxManager: SunlightTaxManager())
    }
}
