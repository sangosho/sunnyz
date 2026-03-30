//
//  AchievementsView.swift
//  SunnyZ
//
//  Achievement gallery view with progress tracking
//

import SwiftUI

struct AchievementsView: View {
    @ObservedObject private var achievementManager = AchievementManager.shared
    @State private var selectedCategory: AchievementCategory = .all
    @State private var showingShareSheet = false
    @State private var shareText = ""
    @State private var selectedAchievement: Achievement?

    enum AchievementCategory: String, CaseIterable {
        case all = "All"
        case caveDwelling = "Cave Dwelling"
        case financial = "Financial"
        case special = "Special"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Category filter
            categoryFilterSection

            Divider()

            // Achievements list
            ScrollView {
                VStack(spacing: 16) {
                    // Progress summary
                    progressSummary

                    // Achievement cards
                    achievementsGrid
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingShareSheet) {
            shareSheet
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Achievements")
                        .font(.headline)

                    Text("\(achievementManager.totalUnlocked) of \(achievementManager.achievements.count) unlocked")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Completion percentage
            Text("\(Int(achievementManager.overallProgress * 100))%")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(achievementManager.overallProgress == 1.0 ? .green : .orange)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Category Filter

    private var categoryFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AchievementCategory.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Progress Summary

    private var progressSummary: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Overall Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(achievementManager.totalUnlocked) unlocked")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 12)

                    RoundedRectangle(cornerRadius: 8)
                        .fill(progressGradient)
                        .frame(width: geo.size.width * CGFloat(achievementManager.overallProgress), height: 12)
                }
            }
            .frame(height: 12)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [.yellow, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Achievements Grid

    private var achievementsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(filteredAchievements) { achievement in
                AchievementCard(achievement: achievement)
                    .onTapGesture {
                        selectedAchievement = achievement
                        shareText = achievementManager.shareText(for: achievement)
                        showingShareSheet = true
                    }
            }
        }
    }

    private var filteredAchievements: [Achievement] {
        if selectedCategory == .all {
            return achievementManager.achievements
        }
        return achievementManager.achievements.filter { $0.category.rawValue == selectedCategory.rawValue }
    }

    // MARK: - Share Sheet

    private var shareSheet: some View {
        VStack(spacing: 20) {
            if let achievement = selectedAchievement {
                HStack(spacing: 16) {
                    Text(achievement.icon)
                        .font(.system(size: 48))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(achievement.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if achievement.isUnlocked, let date = achievement.unlockedAt {
                            Text("Unlocked \(formatDate(date))")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else {
                            Text("Not yet unlocked")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                Text(achievement.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()

                // Share text preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Share Text:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(shareText)
                        .font(.caption)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }

                // Share button
                Button(action: shareAchievement) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)

                // Cancel button
                Button(action: { showingShareSheet = false }) {
                    Text("Cancel")
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func shareAchievement() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareText, forType: .string)

        showingShareSheet = false

        // Show confirmation
        let alert = NSAlert()
        alert.messageText = "Copied to Clipboard"
        alert.informativeText = "Share text copied! Paste it anywhere to share your achievement."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let category: AchievementsView.AchievementCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(category.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.1))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Achievement Card

struct AchievementCard: View {
    let achievement: Achievement

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Text(achievement.icon)
                .font(.system(size: 48))
                .opacity(achievement.isUnlocked ? 1.0 : 0.4)

            // Title
            Text(achievement.title)
                .font(.headline)
                .foregroundColor(achievement.isUnlocked ? .primary : .secondary)

            // Description
            Text(achievement.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            // Progress
            if !achievement.isUnlocked {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Progress")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(Int(achievement.progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 6)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(cardProgressColor)
                                .frame(width: geo.size.width * CGFloat(achievement.progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
            } else if let date = achievement.unlockedAt {
                Text(formatDate(date))
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .frame(height: 200)
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorderColor, lineWidth: 2)
        )
    }

    private var cardBackgroundColor: Color {
        achievement.isUnlocked ? Color(NSColor.controlBackgroundColor) : Color.gray.opacity(0.1)
    }

    private var cardBorderColor: Color {
        achievement.isUnlocked ? Color.yellow.opacity(0.6) : Color.clear
    }

    private var cardProgressColor: LinearGradient {
        LinearGradient(
            colors: [.yellow, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview

struct AchievementsView_Previews: PreviewProvider {
    static var previews: some View {
        AchievementsView()
    }
}
