//
//  PaymentBannerView.swift
//  SunnyZ
//
//  Realistic Apple Pay-style payment success banner shown as a floating window.
//

import SwiftUI

// MARK: - Payment Banner Data

struct PaymentBannerInfo {
    let amount: String
    let title: String
    let subtitle: String
    let icon: String  // SF Symbol name
    let accentColor: Color
    
    static let taxPayment = PaymentBannerInfo(
        amount: "$0.99",
        title: "Payment Successful",
        subtitle: "Sunlight Tax — Brightness restored for 1 hour",
        icon: "creditcard.fill",
        accentColor: .green
    )
    
    static let premiumSubscription = PaymentBannerInfo(
        amount: "$4.99/mo",
        title: "Subscription Active",
        subtitle: "Premium Cave Dweller — Unlimited brightness",
        icon: "crown.fill",
        accentColor: .purple
    )
}

// MARK: - Payment Banner View

struct PaymentBannerView: View {
    let info: PaymentBannerInfo
    let onDismiss: () -> Void
    
    @State private var checkmarkScale: CGFloat = 0
    @State private var checkmarkOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var ringTrim: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Main banner card
            VStack(spacing: 16) {
                // Animated checkmark circle
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(info.accentColor.opacity(0.2), lineWidth: 3)
                        .frame(width: 56, height: 56)
                    
                    // Animated ring fill
                    Circle()
                        .trim(from: 0, to: ringTrim)
                        .stroke(info.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    
                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(info.accentColor)
                        .scaleEffect(checkmarkScale)
                        .opacity(checkmarkOpacity)
                }
                .padding(.top, 4)
                
                // Payment info
                VStack(spacing: 6) {
                    Text(info.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(info.subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .opacity(contentOpacity)
                
                // Amount + payment method row
                HStack(spacing: 12) {
                    // Payment method indicator
                    HStack(spacing: 6) {
                        Image(systemName: info.icon)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("Apple Pay")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Amount
                    Text(info.amount)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.separatorColor).opacity(0.15))
                .cornerRadius(8)
                .opacity(contentOpacity)
            }
            .padding(20)
            .frame(width: 280)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
            )
        }
        .onAppear {
            runAnimation()
        }
    }
    
    private func runAnimation() {
        // Phase 1: Ring draws
        withAnimation(.easeOut(duration: 0.5)) {
            ringTrim = 1.0
        }
        
        // Phase 2: Checkmark pops in
        withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.4)) {
            checkmarkScale = 1.0
            checkmarkOpacity = 1.0
        }
        
        // Phase 3: Content fades in
        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
            contentOpacity = 1.0
        }
        
        // Phase 4: Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            onDismiss()
        }
    }
}

// MARK: - Payment Banner Window Controller

/// Shows the payment banner as a floating borderless window anchored to the top-center of the screen.
@MainActor
final class PaymentBannerController {
    
    private static weak var currentWindow: NSWindow?
    
    static func show(_ info: PaymentBannerInfo) {
        // Dismiss any existing banner first
        currentWindow?.close()
        
        let bannerView = PaymentBannerView(info: info) {
            dismissBanner()
        }
        
        let hostingView = NSHostingView(rootView: bannerView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 220)
        
        // Create a borderless, floating, transparent window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 220),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Position: top-center of the main screen, below the menu bar
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 140  // half of 280 width
            let y = screenFrame.maxY - 30    // just below menu bar area
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Animate in: slide down + fade
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - 140
                let y = screenFrame.maxY - 50
                window.animator().setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        currentWindow = window
    }
    
    static func dismissBanner() {
        guard let window = currentWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            // Slide up
            var origin = window.frame.origin
            origin.y += 20
            window.animator().setFrameOrigin(origin)
        }, completionHandler: {
            Task { @MainActor in
                window.close()
            }
        })
    }
}

// MARK: - Notification Banner (macOS notification style)

/// Data for a simulated macOS notification
struct NotificationBannerInfo {
    let title: String
    let body: String
    let icon: String    // SF Symbol
    let appName: String
    let tintColor: Color
    
    init(title: String, body: String, icon: String = "sun.max.fill", appName: String = "SunnyZ", tintColor: Color = .orange) {
        self.title = title
        self.body = body
        self.icon = icon
        self.appName = appName
        self.tintColor = tintColor
    }
}

/// SwiftUI view that mimics a macOS notification banner
struct NotificationBannerView: View {
    let info: NotificationBannerInfo
    let onDismiss: () -> Void
    
    @State private var appeared = false
    
    var body: some View {
        HStack(spacing: 12) {
            // App icon (mimics the rounded square app icon in real notifications)
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                
                Image(systemName: info.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(info.appName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("now")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Text(info.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(info.body)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(width: 340, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(NSColor.separatorColor).opacity(0.25), lineWidth: 0.5)
        )
        .onAppear {
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onDismiss()
            }
        }
    }
}

/// Shows a simulated macOS notification as a floating window in the top-right corner.
@MainActor
final class NotificationBannerController {
    
    private static weak var currentWindow: NSWindow?
    
    static func show(_ info: NotificationBannerInfo) {
        // Dismiss any existing banner first
        currentWindow?.close()
        
        let bannerView = NotificationBannerView(info: info) {
            dismissBanner()
        }
        
        let hostingView = NSHostingView(rootView: bannerView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 100)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        // Position: top-right of screen, matching real macOS notification placement
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 340 - 16   // 16pt margin from right edge
            let y = screenFrame.maxY - 10          // start slightly above (for slide-in)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // Animate in: slide down + fade
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 1
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.maxX - 340 - 16
                let y = screenFrame.maxY - 30
                window.animator().setFrameOrigin(NSPoint(x: x, y: y))
            }
        }
        
        currentWindow = window
    }
    
    static func dismissBanner() {
        guard let window = currentWindow else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
            // Slide right (mimics real notification dismiss)
            var origin = window.frame.origin
            origin.x += 30
            window.animator().setFrameOrigin(origin)
        }, completionHandler: {
            Task { @MainActor in
                window.close()
            }
        })
    }
}

// MARK: - Preview

struct PaymentBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            PaymentBannerView(info: .taxPayment) { }
            PaymentBannerView(info: .premiumSubscription) { }
        }
        .padding(40)
        .background(Color.gray.opacity(0.2))
    }
}

struct NotificationBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            NotificationBannerView(
                info: NotificationBannerInfo(
                    title: "Sunlight Tax Warning",
                    body: "You've got 30 minutes before your cave-dwelling costs you.",
                    icon: "exclamationmark.triangle.fill",
                    tintColor: .orange
                )
            ) { }
            
            NotificationBannerView(
                info: NotificationBannerInfo(
                    title: "Tax Applied!",
                    body: "Your screen brightness has been reduced to 50%.",
                    icon: "dollarsign.circle.fill",
                    tintColor: .red
                )
            ) { }
        }
        .padding(40)
        .background(Color.gray.opacity(0.3))
    }
}
