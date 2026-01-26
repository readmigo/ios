import SwiftUI

struct MedalsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = MedalManager.shared

    @State private var selectedMedal: Medal?
    @State private var showingDetail = false
    @State private var selectedCategory: MedalCategory?
    @State private var selectedRarity: MedalRarity?
    @State private var viewMode: ViewMode = .grid

    enum ViewMode {
        case grid
        case list
    }

    var body: some View {
        NavigationStack {
            if !authManager.isAuthenticated {
                LoginRequiredView(feature: "medals")
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // Stats Header
                        if let stats = manager.stats {
                            MedalStatsHeader(stats: stats, manager: manager)
                        }

                        // Unlocked Medals Section
                        if !manager.unlockedMedals.isEmpty {
                            unlockedSection
                        }

                        // In Progress Section
                        if !manager.inProgressMedals.isEmpty {
                            inProgressSection
                        }

                        // Category Filter
                        categoryFilterSection

                        // Rarity Filter
                        MedalRarityFilter(selectedRarity: $selectedRarity)

                        // View Mode Toggle
                        viewModeToggle

                        // Medals Grid/List
                        medalsContent

                        Spacer(minLength: 40)
                    }
                    .padding(.vertical)
                }
                .navigationTitle("medal.title".localized)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                viewMode = .grid
                            } label: {
                                Label("Grid", systemImage: "square.grid.2x2")
                            }

                            Button {
                                viewMode = .list
                            } label: {
                                Label("List", systemImage: "list.bullet")
                            }
                        } label: {
                            Image(systemName: viewMode == .grid ? "square.grid.2x2" : "list.bullet")
                        }
                    }
                }
                .elegantRefreshable {
                    await manager.refreshAll()
                }
                .sheet(isPresented: $showingDetail) {
                    if let medal = selectedMedal {
                        MedalDetailView(
                            medal: medal,
                            isUnlocked: manager.isUnlocked(medal.id),
                            unlockedAt: manager.getUserMedal(for: medal.id)?.unlockedAt,
                            progress: manager.getProgress(for: medal.code)
                        )
                    }
                }
                .overlay {
                    if manager.isLoading && manager.allMedals.isEmpty {
                        ProgressView()
                    }
                }
                .task {
                    await manager.refreshAll()
                }
            }
        }
    }

    // MARK: - Unlocked Section

    private var unlockedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "trophy.fill")
                    .foregroundColor(.yellow)
                Text("medal.earned".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
                Text("\(manager.unlockedMedals.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(manager.unlockedMedals) { userMedal in
                        MedalCardView(
                            medal: userMedal.medal,
                            isUnlocked: true,
                            unlockedAt: userMedal.unlockedAt
                        ) {
                            selectedMedal = userMedal.medal
                            showingDetail = true
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - In Progress Section

    private var inProgressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text("medal.inProgress".localized)
                    .font(.title3)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding(.horizontal)

            VStack(spacing: 12) {
                ForEach(manager.inProgressMedals.prefix(5), id: \.medal.id) { item in
                    MedalProgressRow(
                        medal: item.medal,
                        progress: item.progress
                    ) {
                        selectedMedal = item.medal
                        showingDetail = true
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Category Filter Section

    private var categoryFilterSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("medal.categories".localized)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    MedalCategoryChip(
                        category: nil,
                        isSelected: selectedCategory == nil
                    ) {
                        selectedCategory = nil
                    }

                    ForEach(MedalCategory.allCases, id: \.self) { category in
                        MedalCategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        HStack {
            Text("medal.all".localized)
                .font(.title3)
                .fontWeight(.bold)

            Spacer()

            Text("\(filteredMedals.count) \("medal.count".localized)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Filtered Medals

    private var filteredMedals: [Medal] {
        var medals = manager.allMedals

        if let category = selectedCategory {
            medals = medals.filter { $0.category == category }
        }

        if let rarity = selectedRarity {
            medals = medals.filter { $0.rarity == rarity }
        }

        return medals
    }

    // MARK: - Medals Content

    @ViewBuilder
    private var medalsContent: some View {
        if viewMode == .grid {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredMedals) { medal in
                    MedalCardView(
                        medal: medal,
                        isUnlocked: manager.isUnlocked(medal.id),
                        unlockedAt: manager.getUserMedal(for: medal.id)?.unlockedAt,
                        progress: manager.getProgress(for: medal.code)
                    ) {
                        selectedMedal = medal
                        showingDetail = true
                    }
                }
            }
            .padding(.horizontal)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filteredMedals) { medal in
                    CompactMedalCard(
                        medal: medal,
                        isUnlocked: manager.isUnlocked(medal.id),
                        progress: manager.getProgress(for: medal.code)
                    ) {
                        selectedMedal = medal
                        showingDetail = true
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Medal Stats Header

struct MedalStatsHeader: View {
    let stats: MedalStats
    let manager: MedalManager

    var body: some View {
        VStack(spacing: 16) {
            // Overall progress
            HStack(spacing: 20) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: stats.unlockedPercentage)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(stats.unlockedPercentage * 100))")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("medal.collection".localized)
                        .font(.headline)

                    Text("\(stats.totalUnlocked) / \(stats.totalMedals)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Rarity breakdown
                    HStack(spacing: 4) {
                        ForEach(MedalRarity.allCases, id: \.self) { rarity in
                            let count = manager.unlockedByRarity[rarity] ?? 0
                            if count > 0 {
                                HStack(spacing: 2) {
                                    Circle()
                                        .fill(rarity.color)
                                        .frame(width: 8, height: 8)
                                    Text("\(count)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        }
        .padding(.horizontal)
    }
}
