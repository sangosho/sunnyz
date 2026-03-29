//
//  SettingsView.swift
//  SunnyZ
//
//  Settings panel with tabbed interface for Notifications, Tax Settings, and About
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @ObservedObject var taxManager: SunlightTaxManager
    
    @Environment(\.dismiss) private var dismiss
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

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .notifications: return "bell.fill"
            case .taxSettings: return "dollarsign.circle.fill"
            case .achievements: return "trophy.fill"
            case .about: return "info.circle.fill"
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
        .sheet(isPresented: $showingDebugPanel) {
            DebugPanelView()
        }
    }
    
    // MARK: - Easter Egg Handler
    
    private func handleVersionTap() {
        versionClickCount += 1
        
        // Reset timer if already running
        versionClickTimer?.invalidate()
        
        // Start new timer to reset count after 3 seconds
        versionClickTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            versionClickCount = 0
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
    }
    
    private var toolbar: some View {
        HStack(spacing: 0) {
            // Tab buttons
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    TabButton(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                }
            }
            
            Spacer()
            
            // Done button
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal)
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
            }
            .frame(width: 80)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notifications Tab

struct NotificationsTab: View {
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var snarkManager = SnarkManager.shared
    @State private var showingPreviewMessage = false
    @State private var previewMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Master Toggle Section
            VStack(alignment: .leading, spacing: 12) {
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
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Permission denied. Enable in System Settings → Notifications.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 20)
                }
            }
            
            if notificationManager.notificationsEnabled {
                Divider()
                
                // Warning Notifications
                VStack(alignment: .leading, spacing: 12) {
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
                        .padding(.leading, 20)
                    }
                }
                
                Divider()
                
                // Snarky Reminders Section
                VStack(alignment: .leading, spacing: 16) {
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
                            .padding(.leading, 20)
                            
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
                            .padding(.leading, 20)
                            
                            // Preview Button
                            Button(action: showPreview) {
                                HStack {
                                    Image(systemName: "eye.fill")
                                    Text("Preview Message")
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.leading, 20)
                            
                            // Test Button
                            Button(action: sendTestReminder) {
                                HStack {
                                    Image(systemName: "bell.badge.fill")
                                    Text("Send Test Reminder")
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .padding(.leading, 20)
                            .disabled(!notificationManager.isAuthorized)
                            
                            // Info text
                            Text("Only shown when in darkness, paused when taxed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 20)
                        }
                    }
                }
                
                Divider()
                
                // Daily Summary
                VStack(alignment: .leading, spacing: 12) {
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
                        .padding(.leading, 20)
                        
                        Text("Daily cave-dwelling report with stats and achievements")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        .padding(.leading, 20)
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

// MARK: - Tax Settings Tab

struct TaxSettingsTab: View {
    @ObservedObject var taxManager: SunlightTaxManager
    @StateObject private var settings = SettingsManager.shared
    @State private var showingCalibration = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Tax Threshold Section
            VStack(alignment: .leading, spacing: 16) {
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
                
                // Current threshold info
                HStack {
                    Text("Current setting:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(settings.formattedTaxThreshold)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
                
                // Warning timing
                HStack {
                    Text("Warning at:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatWarningTime())
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            
            Divider()
            
            // Menu Bar Display
            VStack(alignment: .leading, spacing: 12) {
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
            
            Divider()
            
            // Brightness Limit Preview
            VStack(alignment: .leading, spacing: 12) {
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
    @StateObject private var settings = SettingsManager.shared
    @Binding var showingResetConfirmation: Bool
    
    // MARK: - Debug Callbacks & State
    let onVersionTap: () -> Void
    let debugModeEnabled: Bool
    let onDebugModeChange: (Bool) -> Void
    let onOpenDebugPanel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // App Info
            VStack(alignment: .leading, spacing: 16) {
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
            
            Divider()
            
            // Lux Sensor Info
            VStack(alignment: .leading, spacing: 12) {
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
            
            Divider()
            
            // Stats Summary
            VStack(alignment: .leading, spacing: 12) {
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
            
            Divider()
            
            // Launch at Login
            VStack(alignment: .leading, spacing: 12) {
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
            
            Divider()
            
            // Reset Button
            VStack(alignment: .leading, spacing: 12) {
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
            
            // MARK: - Developer Section (Debug Mode)
            if debugModeEnabled {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
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
        SettingsView(taxManager: SunlightTaxManager())
    }
}
