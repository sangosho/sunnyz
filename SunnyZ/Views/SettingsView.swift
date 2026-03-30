//
//  SettingsView.swift
//  SunnyZ
//
//  Settings panel with tabbed interface for Notifications, Tax Settings, and About
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject var taxManager: SunlightTaxManager
    
    @State private var selectedTab: SettingsTab = .notifications
    @State private var showingResetConfirmation = false
    @State private var showingCalibrationSheet = false
    
    // MARK: - Debug Mode State
    @State private var showingDebugPanel = false
    @State private var versionClickCount = 0
    @State private var versionClickTimer: Timer?
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case notifications = "Notifications"
        case taxSettings = "Tax Settings"
        case achievements = "Achievements"
        case about = "About"
        #if DEBUG
        case debug = "Debug"
        #endif

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .notifications: return "bell.fill"
            case .taxSettings: return "dollarsign.circle.fill"
            case .achievements: return "trophy.fill"
            case .about: return "info.circle.fill"
            #if DEBUG
            case .debug: return "ladybug.fill"
            #endif
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar with tabs
            toolbar
            
            Divider()
            
            // Tab content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .notifications:
                        NotificationsTab()
                    case .taxSettings:
                        TaxSettingsTab(taxManager: taxManager)
                    case .achievements:
                        AchievementsTabWrapper()
                    case .about:
                        AboutTab(
                            taxManager: taxManager,
                            showingResetConfirmation: $showingResetConfirmation,
                            onVersionTap: handleVersionTap,
                            debugModeEnabled: settings.debugModeEnabled,
                            onDebugModeChange: { settings.debugModeEnabled = $0 },
                            onOpenDebugPanel: { showingDebugPanel = true }
                        )
                    #if DEBUG
                    case .debug:
                        DebugPanelView()
                    #endif
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 520)
        .alert("Reset All Stats?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetAllStats()
            }
        } message: {
            Text("This will clear all your tax payment history, darkness time, and achievements. This action cannot be undone.")
        }
        #if DEBUG
        .sheet(isPresented: $showingDebugPanel) {
            DebugPanelView()
        }
        #endif
        .onDisappear {
            invalidateTimers()
            // Force SwiftUI to clean up any pending animations
            withAnimation(.none) {}
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
            invalidateTimers()
        }
    }
    
    // MARK: - Easter Egg Handler
    
    private func handleVersionTap() {
        #if DEBUG
        versionClickCount += 1
        
        // Reset timer if already running
        versionClickTimer?.invalidate()
        
        // Start new timer to reset count after 3 seconds
        versionClickTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [self] _ in
            Task { @MainActor in
                versionClickCount = 0
            }
        }
        
        // Enable debug mode after 5 clicks
        if versionClickCount >= 5 {
            versionClickTimer?.invalidate()
            versionClickCount = 0
            settings.debugModeEnabled = true
            
            // Provide haptic feedback
            let generator = NSHapticFeedbackManager.defaultPerformer
            generator.perform(.generic, performanceTime: .default)
        }
        #endif
    }
    
    // MARK: - Cleanup
    
    private func invalidateTimers() {
        versionClickTimer?.invalidate()
        versionClickTimer = nil
    }
    
    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.allCases) { tab in
                TabButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: { selectedTab = tab }
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16))
                Text(tab.rawValue)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notifications Tab

struct NotificationsTab: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var notificationManager = NotificationManager.shared
    @ObservedObject private var snarkManager = SnarkManager.shared
    @State private var showingPreviewMessage = false
    @State private var previewMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Master Toggle Section
            SettingsSection {
                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                        .frame(width: 24)
                    Text("Notifications")
                        .font(.headline)
                }
                
                Toggle("Enable Notifications", isOn: $notificationManager.notificationsEnabled)
                    .onChange(of: notificationManager.notificationsEnabled) { newValue in
                        if newValue {
                            notificationManager.requestAuthorization()
                        }
                    }
                
                if notificationManager.notificationsEnabled && !notificationManager.isAuthorized {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            if !Bundle.main.bundlePath.hasSuffix(".app") {
                                Text("Notifications require running from a .app bundle (not swift run).")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Permission denied. Enable in System Settings → Notifications.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Open Notification Settings") {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)
                }
            }
            
            if notificationManager.notificationsEnabled {
                // Warning Notifications
                SettingsSection {
                    Toggle("Warning Notifications", isOn: $notificationManager.warningNotificationsEnabled)
                    
                    if notificationManager.warningNotificationsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            NotificationFeatureRow(
                                icon: "30.circle.fill",
                                text: "30-minute warning before tax"
                            )
                            NotificationFeatureRow(
                                icon: "5.circle.fill",
                                text: "5-minute final warning"
                            )
                            NotificationFeatureRow(
                                icon: "dollarsign.circle.fill",
                                text: "Tax applied notification"
                            )
                        }
                        .padding(.leading, 4)
                    }
                }
                
                // Snarky Reminders Section
                SettingsSection {
                    HStack {
                        Image(systemName: "text.bubble.fill")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        Text("Go Outside Reminders")
                            .font(.headline)
                    }
                    
                    Toggle("Enable Reminders", isOn: $snarkManager.remindersEnabled)
                    
                    if snarkManager.remindersEnabled {
                        VStack(alignment: .leading, spacing: 16) {
                            // Reminder Interval Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Reminder Frequency")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("Interval", selection: $snarkManager.reminderInterval) {
                                    ForEach(SnarkManager.ReminderInterval.allCases) { interval in
                                        Text(interval.displayName)
                                            .tag(interval)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Snark Level Slider
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Snark Level")
                                        .font(.subheadline)
                                    Spacer()
                                    Text("\(snarkManager.snarkLevel.emoji) \(snarkManager.snarkLevel.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Picker("Snark Level", selection: $snarkManager.snarkLevel) {
                                    ForEach(SnarkManager.SnarkLevel.allCases) { level in
                                        Text(level.displayName)
                                            .tag(level)
                                    }
                                }
                                .pickerStyle(.segmented)
                                
                                Text(snarkManager.snarkLevel.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Action buttons
                            HStack(spacing: 8) {
                                Button(action: showPreview) {
                                    HStack {
                                        Image(systemName: "eye.fill")
                                        Text("Preview")
                                    }
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: sendTestReminder) {
                                    HStack {
                                        Image(systemName: "bell.badge.fill")
                                        Text("Test Reminder")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .tint(.purple)
                                .disabled(!notificationManager.isAuthorized)
                            }
                            
                            Text("Only shown when in darkness, paused when taxed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Daily Summary
                SettingsSection {
                    Toggle("Daily Summary", isOn: $notificationManager.dailySummaryEnabled)
                    
                    if notificationManager.dailySummaryEnabled {
                        HStack {
                            Text("Summary Time:")
                                .font(.subheadline)
                            
                            DatePicker(
                                "",
                                selection: $notificationManager.dailySummaryTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .frame(width: 100)
                            
                            Spacer()
                        }
                        
                        Text("Daily cave-dwelling report with stats and achievements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .alert("Preview", isPresented: $showingPreviewMessage) {
            Button("OK") { }
            Button("Another") {
                showPreview()
            }
        } message: {
            Text(previewMessage)
        }
    }
    
    private func showPreview() {
        previewMessage = snarkManager.previewMessage(for: snarkManager.snarkLevel)
        showingPreviewMessage = true
    }
    
    private func sendTestReminder() {
        snarkManager.sendTestReminder()
    }
}

struct NotificationFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Settings Section Container

/// Reusable grouped section with rounded background, matching macOS System Settings style
struct SettingsSection<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - Tax Settings Tab

struct TaxSettingsTab: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @ObservedObject private var settings = SettingsManager.shared
    @State private var showingCalibration = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tax Threshold Section
            SettingsSection {
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Tax Threshold")
                        .font(.headline)
                }
                
                Text("How long you can stay indoors before the tax kicks in")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Picker("Threshold", selection: $settings.taxThresholdHours) {
                    ForEach(SettingsManager.TaxThreshold.allCases) { threshold in
                        Text(threshold.displayName)
                            .tag(threshold)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.taxThresholdHours) { _ in
                    // Threshold change is handled by the settings manager
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Text("Current:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(settings.formattedTaxThreshold)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Warning at:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(formatWarningTime())
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Menu Bar Display
            SettingsSection {
                HStack {
                    Image(systemName: "menubar.rectangle")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Menu Bar Display")
                        .font(.headline)
                }
                
                Toggle("Show countdown in menu bar", isOn: $settings.showCountdownInMenuBar)
                
                Text("Display time until tax in the menu bar icon tooltip")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Brightness Limit Preview
            SettingsSection {
                HStack {
                    Image(systemName: "sun.min.fill")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    Text("Brightness Limit Preview")
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: "sun.max.fill")
                        .foregroundColor(.yellow)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.yellow.opacity(0.5))
                                .frame(width: geo.size.width * 0.5)
                        }
                    }
                    .frame(height: 20)
                    
                    Image(systemName: "sun.min.fill")
                        .foregroundColor(.gray)
                }
                
                Text("When taxed, screen brightness is limited to 50%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatWarningTime() -> String {
        let hours = settings.taxThresholdHours.rawValue
        if hours >= 1 {
            return "\(hours - 1)h 30m"
        }
        return "30m"
    }
}

// MARK: - About Tab

struct AboutTab: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @ObservedObject private var settings = SettingsManager.shared
    @Binding var showingResetConfirmation: Bool
    
    // MARK: - Debug Callbacks & State
    let onVersionTap: () -> Void
    let debugModeEnabled: Bool
    let onDebugModeChange: (Bool) -> Void
    let onOpenDebugPanel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // App Info
            SettingsSection {
                HStack(spacing: 16) {
                    // App Icon placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 64, height: 64)
                        
                        Text("☀️")
                            .font(.system(size: 32))
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SunnyZ")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Version 1.0.0 (Build 1.0.0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .onTapGesture {
                                onVersionTap()
                            }
                            .contentShape(Rectangle())
                            .help("Tap 5 times to enable debug mode")
                    }
                }
                
                Text("Late-stage capitalism meets touch grass™")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
            }
            
            // Lux Sensor Info
            SettingsSection {
                HStack {
                    Image(systemName: "light.max")
                        .foregroundColor(.yellow)
                        .frame(width: 24)
                    Text("Light Sensor")
                        .font(.headline)
                }
                
                HStack {
                    Image(systemName: taxManager.luxSensorManager.hasALSSensor ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(taxManager.luxSensorManager.hasALSSensor ? .green : .orange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(taxManager.luxSensorManager.sensorStatusDescription)
                            .font(.subheadline)
                        Text("Current reading: \(Int(taxManager.currentLux)) lux")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Accuracy indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(accuracyColor)
                            .frame(width: 8, height: 8)
                        Text(taxManager.luxAccuracy.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stats Summary
            SettingsSection {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    Text("Your Stats")
                        .font(.headline)
                }
                
                HStack {
                    Text("Total Tax Paid:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taxManager.formattedTotalTax)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                }
                
                HStack {
                    Text("Time in Darkness:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(taxManager.formattedTimeInDarkness)
                        .fontWeight(.semibold)
                }
                
                if let lastSunlight = taxManager.lastSunlightDate {
                    HStack {
                        Text("Last Outside:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatRelativeTime(from: lastSunlight))
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Launch at Login
            SettingsSection {
                HStack {
                    Image(systemName: "power")
                        .foregroundColor(.green)
                        .frame(width: 24)
                    Text("Startup")
                        .font(.headline)
                }
                
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                
                Text("Start SunnyZ automatically when you log in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Reset Button
            SettingsSection {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(.red)
                        .frame(width: 24)
                    Text("Reset")
                        .font(.headline)
                }
                
                Button(action: { showingResetConfirmation = true }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset All Stats")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Text("Clear all tax history and achievements. Cannot be undone.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            #if DEBUG
            // MARK: - Developer Section (Debug Mode)
            if debugModeEnabled {
                SettingsSection {
                    HStack {
                        Image(systemName: "ladybug.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("Developer")
                            .font(.headline)
                    }
                    
                    Toggle("Debug Mode", isOn: Binding(
                        get: { debugModeEnabled },
                        set: { onDebugModeChange($0) }
                    ))
                    
                    Button(action: { onOpenDebugPanel() }) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Open Debug Panel")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Build: 1.0.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Version: 1.0.0 (Sprint 2)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            #endif
        }
    }
    
    private var accuracyColor: Color {
        switch taxManager.luxAccuracy {
        case .accurate: return .green
        case .estimated: return .orange
        case .unavailable: return .red
        }
    }
    
    private func formatRelativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Achievements Tab Wrapper

struct AchievementsTabWrapper: View {
    var body: some View {
        AchievementsView()
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(taxManager: SunlightTaxManager.shared)
    }
}
