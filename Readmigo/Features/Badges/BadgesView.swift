import SwiftUI

struct BadgesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = BadgesManager.shared
    @State private var selectedBadge: Badge?
    @State private var showingDetail = false
    @State private var selectedCategory: BadgeCategory?

    var body: some View {
        NavigationStack {
            if !authManager.isAuthenticated {
                LoginRequiredView(feature: "achievements")
            } else {
            ScrollView {
                VStack(spacing: 24) {
                    // Earned Badges Section
                    if !manager.earnedBadges.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                Text("badges.earned".localized)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Spacer()
                                Text("\(manager.earnedBadges.count)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(manager.earnedBadges) { userBadge in
                                        BadgeCardView(
                                            badge: userBadge.badge,
                                            isEarned: true,
                                            earnedDate: userBadge.earnedAt
                                        ) {
                                            selectedBadge = userBadge.badge
                                            showingDetail = true
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // In Progress Section
                    if !manager.inProgressBadges.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.blue)
                                Text("badges.inProgress".localized)
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Spacer()
                            }
                            .padding(.horizontal)

                            VStack(spacing: 12) {
                                ForEach(manager.inProgressBadges) { progress in
                                    BadgeProgressRow(progress: progress) {
                                        selectedBadge = progress.badge
                                        showingDetail = true
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    // Category Filter
                    VStack(alignment: .leading, spacing: 16) {
                        Text("badges.all".localized)
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                BadgeCategoryChip(
                                    title: "common.all".localized,
                                    icon: "square.grid.2x2",
                                    isSelected: selectedCategory == nil
                                ) {
                                    selectedCategory = nil
                                }

                                ForEach(BadgeCategory.allCases, id: \.self) { category in
                                    BadgeCategoryChip(
                                        title: category.displayName,
                                        icon: category.icon,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Badges Grid
                    let filteredBadges = selectedCategory == nil
                        ? manager.allBadges
                        : manager.allBadges.filter { $0.category == selectedCategory }

                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 100), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredBadges) { badge in
                            BadgeCardView(
                                badge: badge,
                                isEarned: manager.isEarned(badge),
                                earnedDate: manager.userBadge(for: badge)?.earnedAt,
                                progress: manager.progress(for: badge)
                            ) {
                                selectedBadge = badge
                                showingDetail = true
                            }
                        }
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("badges.title".localized)
            .elegantRefreshable {
                await manager.refreshAll()
            }
            .sheet(isPresented: $showingDetail) {
                if let badge = selectedBadge {
                    BadgeDetailView(
                        badge: badge,
                        isEarned: manager.isEarned(badge),
                        earnedDate: manager.userBadge(for: badge)?.earnedAt,
                        progress: manager.progress(for: badge)
                    )
                }
            }
            .overlay {
                if manager.isLoading && manager.allBadges.isEmpty {
                    ProgressView()
                }
            }
            .task {
                await manager.refreshAll()
            }
            }
        }
    }
}

// MARK: - Badge Progress Row

struct BadgeProgressRow: View {
    let progress: BadgeProgress
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: progress.badge.tier.color).opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: progress.badge.category.icon)
                        .foregroundColor(Color(hex: progress.badge.tier.color))
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progress.badge.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(progress.progressPercent))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: progress.progressPercent / 100)
                        .tint(Color(hex: progress.badge.tier.color))

                    Text("\(progress.currentValue) / \(progress.targetValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Badge Category Chip

private struct BadgeCategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}
