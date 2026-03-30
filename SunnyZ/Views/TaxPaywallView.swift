//
//  TaxPaywallView.swift
//  SunnyZ
//
//  Tax paywall window content
//

import SwiftUI

struct TaxPaywallView: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 12) {
                Text("💸")
                    .font(.system(size: 64))
                
                Text("SUNLIGHT TAX DUE")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Text("Your cave-dwelling behavior has consequences")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Tax breakdown
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Time in Darkness")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taxManager.formattedTimeInDarkness)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Brightness Penalty")
                        .foregroundColor(.secondary)
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
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Benefits
            VStack(alignment: .leading, spacing: 8) {
                Text("What You Get")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                BenefitRow(icon: "☀️", text: "Full brightness restored (1 hour)")
                BenefitRow(icon: "💻", text: "Continue coding in the dark")
                BenefitRow(icon: "😴", text: "Maintain your cave lifestyle")
            }
            
            Spacer()
            
            // Pay button
            Button(action: payTax) {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
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
            .cornerRadius(10)
            .disabled(isProcessing)
            .buttonStyle(.plain)
            
            Button("Go Outside Instead (Free)") {
                dismissWindow()
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .buttonStyle(.plain)
            
            // Subtle debug mode indicator (visible but not distracting)
            if taxManager.debugModeEnabled {
                Text("🧪 Test Mode — No real charges")
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
        .padding()
        .frame(width: 320, height: taxManager.debugModeEnabled ? 450 : 420)
    }
    
    private func payTax() {
        // Guard: can only pay tax when actually taxed
        guard taxManager.taxStatus == .taxed else {
            let alert = NSAlert()
            alert.messageText = "No Tax Due"
            alert.informativeText = "You haven't been taxed yet. Spend \(taxManager.formattedTimeUntilTax) more in darkness to incur the sunlight tax."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        isProcessing = true

        Task { @MainActor in
            defer { isProcessing = false }
            
            do {
                try await taxManager.payTax()
                dismissWindow()
                
                // Small delay
                try await Task.sleep(for: .milliseconds(100))
                
                let alert = NSAlert()
                alert.messageText = "Tax Paid! ✅"
                alert.informativeText = "Brightness restored for 1 hour."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Great")
                alert.runModal()
            } catch {
                // Handle error
            }
        }
    }
    
    private func dismissWindow() {
        NSApplication.shared.keyWindow?.close()
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

struct TaxPaywallView_Previews: PreviewProvider {
    static var previews: some View {
        TaxPaywallView(taxManager: SunlightTaxManager())
    }
}
