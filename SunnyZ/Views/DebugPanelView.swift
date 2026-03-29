//
//  DebugPanelView.swift
//  SunnyZ
//
//  Debug panel for testing and development
//

import SwiftUI
import UserNotifications

/// Debug panel for testing app features and states
struct DebugPanelView: View {
    
    // MARK: - Managers
    @StateObject private var settings = SettingsManager.shared
    @StateObject private var luxManager = LuxSensorManager.shared
    @StateObject private var taxManager = SunlightTaxManager.shared
    @StateObject private var achievementManager = AchievementManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var snarkManager = SnarkManager.shared
    
    // MARK: - Lux Simulator State
    @State private var luxSliderValue: Double = 200
    @State private var overrideRealSensor: Bool = false
    
    // MARK: - Tax Override State
    @State private var editableTimeInDarkness: String = "0"
    
    // MARK: - Time Acceleration State
    @State private var timeMultiplier: Double = 1
    
    // MARK: - View Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection
                
                Divider()
                    .background(debugAccentColor)
                
                // Debug Sections
                luxSimulatorSection
                taxStateOverrideSection
                achievementTriggerSection
                notificationTestingSection
                timeAccelerationSection
            }
            .padding()
        }
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 600)
        .onAppear {
            loadInitialValues()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Image(systemName: "ladybug.fill")
                .font(.title2)
                .foregroundColor(debugAccentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Debug Panel")
                    .font(.headline)
                Text("Development & Testing Tools")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("Debug Mode", isOn: $settings.debugModeEnabled)
                .toggleStyle(.switch)
        }
    }
    
    // MARK: - Lux Simulator Section
    
    private var luxSimulatorSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "light.max")
                        .foregroundColor(debugAccentColor)
                    Text("Lux Simulator")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                Divider()
                
                // Current value display
                HStack {
                    Text("Current Lux:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(luxSliderValue))")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(debugAccentColor)
                    Spacer()
                    
                    // Accuracy indicator
                    HStack(spacing: 4) {
                        Image(systemName: luxManager.accuracy.icon)
                            .foregroundColor(accuracyColor)
                            .font(.caption)
                        Text(luxManager.accuracy.displayText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Slider
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $luxSliderValue, in: 0...1000, step: 1)
                        .tint(debugAccentColor)
                        .onChange(of: luxSliderValue) { newValue in
                            if overrideRealSensor {
                                luxManager.setDebugOverride(newValue)
                            }
                        }
                    
                    HStack {
                        Text("0")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("500")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("1000")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Override toggle
                Toggle("Override Real Sensor", isOn: $overrideRealSensor)
                    .onChange(of: overrideRealSensor) { isOn in
                        if isOn {
                            luxManager.setDebugOverride(luxSliderValue)
                        } else {
                            luxManager.clearDebugOverride()
                        }
                    }
                
                // Quick preset buttons
                Text("Presets:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                FlowLayout(spacing: 8) {
                    LuxPresetButton(title: "Pitch Black", lux: 0, icon: "moon.fill") {
                        setLuxValue(0)
                    }
                    LuxPresetButton(title: "Dim Room", lux: 30, icon: "lamp.desk.fill") {
                        setLuxValue(30)
                    }
                    LuxPresetButton(title: "Office", lux: 200, icon: "building.2.fill") {
                        setLuxValue(200)
                    }
                    LuxPresetButton(title: "Window Light", lux: 500, icon: "window.awning") {
                        setLuxValue(500)
                    }
                    LuxPresetButton(title: "Direct Sun", lux: 1000, icon: "sun.max.fill") {
                        setLuxValue(1000)
                    }
                }
            }
        } label: {
            Label("Lux Simulator", systemImage: "light.max")
                .font(.headline)
                .foregroundColor(debugAccentColor)
        }
        .groupBoxStyle(DebugGroupBoxStyle())
    }
    
    // MARK: - Tax State Override Section
    
    private var taxStateOverrideSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Force status buttons
                Text("Force Tax Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    StatusButton(title: "Exempt", color: .green) {
                        taxManager.forceTaxStatus(SunlightTaxManager.TaxStatus.exempt)
                    }
                    StatusButton(title: "Warning", color: .orange) {
                        taxManager.forceTaxStatus(SunlightTaxManager.TaxStatus.warning)
                    }
                    StatusButton(title: "Taxed", color: .red) {
                        taxManager.forceTaxStatus(SunlightTaxManager.TaxStatus.taxed)
                    }
                    StatusButton(title: "Premium", color: .purple) {
                        taxManager.forceTaxStatus(SunlightTaxManager.TaxStatus.premium)
                    }
                }
                
                Divider()
                
                // Quick actions
                HStack(spacing: 8) {
                    Button {
                        // Skip to taxed (4+ hours in darkness)
                        taxManager.forceTimeInDarkness(4 * 3600 + 60) // 4 hours + 1 minute
                    } label: {
                        Label("Skip to Taxed", systemImage: "forward.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Button {
                        taxManager.resetDarknessTimer()
                        editableTimeInDarkness = "0"
                    } label: {
                        Label("Reset Timer", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                
                // Editable time in darkness
                HStack {
                    Text("Time in Darkness (seconds):")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Seconds", text: $editableTimeInDarkness)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                        .font(.system(.body, design: .monospaced))
                    
                    Button("Apply") {
                        if let seconds = TimeInterval(editableTimeInDarkness) {
                            taxManager.forceTimeInDarkness(seconds)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(debugAccentColor)
                }
                
                // Current status display
                HStack {
                    Text("Current Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(taxManager.taxStatus.icon)
                    Text("\(taxManager.taxStatus)")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
        } label: {
            Label("Tax State Override", systemImage: "dollarsign.circle")
                .font(.headline)
                .foregroundColor(debugAccentColor)
        }
        .groupBoxStyle(DebugGroupBoxStyle())
    }
    
    // MARK: - Achievement Trigger Section
    
    private var achievementTriggerSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Achievement list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(achievementManager.achievements) { achievement in
                        AchievementDebugRow(
                            achievement: achievement,
                            onUnlock: {
                                unlockAchievement(achievement)
                            }
                        )
                    }
                }
                
                Divider()
                
                // Reset button
                Button {
                    achievementManager.resetAchievements()
                } label: {
                    Label("Reset All Achievements", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        } label: {
            Label("Achievement Trigger", systemImage: "trophy")
                .font(.headline)
                .foregroundColor(debugAccentColor)
        }
        .groupBoxStyle(DebugGroupBoxStyle())
    }
    
    // MARK: - Notification Testing Section
    
    private var notificationTestingSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                FlowLayout(spacing: 8) {
                    Button {
                        notificationManager.sendTestWarningNotification()
                    } label: {
                        Label("Warning", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        notificationManager.sendTestTaxAppliedNotification()
                    } label: {
                        Label("Tax Applied", systemImage: "dollarsign.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    
                    Button {
                        notificationManager.sendTestDailySummary()
                    } label: {
                        Label("Daily Summary", systemImage: "chart.bar")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        snarkManager.sendTestReminder()
                    } label: {
                        Label("Snarky Reminder", systemImage: "text.bubble")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
            }
        } label: {
            Label("Notification Testing", systemImage: "bell.badge")
                .font(.headline)
                .foregroundColor(debugAccentColor)
        }
        .groupBoxStyle(DebugGroupBoxStyle())
    }
    
    // MARK: - Time Acceleration Section
    
    private var timeAccelerationSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                // Current multiplier display
                HStack {
                    Text("Time Multiplier:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(Int(timeMultiplier))x")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(debugAccentColor)
                    Spacer()
                }
                
                // Slider
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: $timeMultiplier, in: 1...60, step: 1)
                        .tint(debugAccentColor)
                        .onChange(of: timeMultiplier) { newValue in
                            taxManager.setTimeAcceleration(newValue)
                        }
                    
                    HStack {
                        Text("1x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("30x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("60x")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Preset buttons
                HStack(spacing: 8) {
                    TimeMultiplierButton(label: "1x", multiplier: 1, current: $timeMultiplier)
                    TimeMultiplierButton(label: "5x", multiplier: 5, current: $timeMultiplier)
                    TimeMultiplierButton(label: "10x", multiplier: 10, current: $timeMultiplier)
                    TimeMultiplierButton(label: "60x", multiplier: 60, current: $timeMultiplier)
                }
                
                // Reset button
                Button {
                    timeMultiplier = 1
                    taxManager.setTimeAcceleration(1)
                } label: {
                    Label("Reset to 1x", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                
                // Description
                Text("Accelerates time tracking for faster testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        } label: {
            Label("Time Acceleration", systemImage: "speedometer")
                .font(.headline)
                .foregroundColor(debugAccentColor)
        }
        .groupBoxStyle(DebugGroupBoxStyle())
    }
    
    // MARK: - Helpers
    
    private var debugAccentColor: Color {
        Color.orange
    }
    
    private var accuracyColor: Color {
        switch luxManager.accuracy {
        case .accurate: return .green
        case .estimated: return .orange
        case .unavailable: return .red
        }
    }
    
    private func loadInitialValues() {
        luxSliderValue = luxManager.currentLux
        editableTimeInDarkness = String(Int(taxManager.timeInDarkness))
        timeMultiplier = taxManager.timeAcceleration
    }
    
    private func setLuxValue(_ value: Double) {
        luxSliderValue = value
        if overrideRealSensor {
            luxManager.setDebugOverride(value)
        }
    }
    
    private func unlockAchievement(_ achievement: Achievement) {
        // Find the index and unlock via manager
        if let index = achievementManager.achievements.firstIndex(where: { $0.id == achievement.id }) {
            // Use reflection or direct method if available
            // For now, we'll use the manager's unlockAchievement method if it exists
            // Otherwise, we can manipulate the achievement directly
            let unlockedAchievement = achievement.unlocked()
            achievementManager.achievements[index] = unlockedAchievement
            achievementManager.saveAchievements()
        }
    }
}

// MARK: - Supporting Views

/// Custom GroupBox style for debug UI
struct DebugGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            configuration.label
            configuration.content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

/// Flow layout for wrapping buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + rowHeight
        }
    }
}

/// Lux preset button
struct LuxPresetButton: View {
    let title: String
    let lux: Double
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
                Text("\(Int(lux))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 60)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

/// Status button for tax state
struct StatusButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .controlSize(.small)
    }
}

/// Achievement row for debug panel
struct AchievementDebugRow: View {
    let achievement: Achievement
    let onUnlock: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Text(achievement.icon)
                .font(.title3)
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(achievement.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Status / Action
            if achievement.isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.caption)
            } else {
                Button("Unlock") {
                    onUnlock()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.orange)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Time multiplier button
struct TimeMultiplierButton: View {
    let label: String
    let multiplier: Double
    @Binding var current: Double
    
    var isSelected: Bool {
        current == multiplier
    }
    
    var body: some View {
        Button {
            current = multiplier
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .orange : .secondary)
        .controlSize(.small)
    }
}

// Note: Manager extensions (debug overrides, forceTaxStatus, etc.) are defined
// in their respective manager files to avoid duplicate declarations.

// MARK: - TaxStatus String Extension

extension SunlightTaxManager.TaxStatus: CustomStringConvertible {
    var description: String {
        switch self {
        case .exempt: return "Exempt"
        case .warning: return "Warning"
        case .taxed: return "Taxed"
        case .premium: return "Premium"
        }
    }
}

// MARK: - Preview

struct DebugPanelView_Previews: PreviewProvider {
    static var previews: some View {
        DebugPanelView()
    }
}
