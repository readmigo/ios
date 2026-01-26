import SwiftUI

struct MedalDetailView: View {
    let medal: Medal
    let isUnlocked: Bool
    let unlockedAt: Date?
    let progress: MedalProgress?

    @Environment(\.dismiss) private var dismiss
    @State private var isRotating = false
    @State private var showShareSheet = false
    @State private var globalStats: MedalGlobalStats?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Medal 3D Display Area
                    medalDisplaySection

                    // Medal Info
                    medalInfoSection

                    // Status Section
                    statusSection

                    // Unlock Requirement
                    requirementSection

                    // Design Story
                    if let story = medal.designStory {
                        designStorySection(story: story)
                    }

                    // Global Stats
                    if let stats = globalStats {
                        globalStatsSection(stats: stats)
                    }

                    // Share Button (if unlocked)
                    if isUnlocked {
                        shareSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("medal.detail".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadGlobalStats()
            }
        }
    }

    // MARK: - Medal Display Section

    private var medalDisplaySection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                medal.rarity.glowColor,
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 60,
                            endRadius: 140
                        )
                    )
                    .frame(width: 240, height: 240)
                    .opacity(isUnlocked ? 1 : 0.3)

                // Medal circle with gradient
                Circle()
                    .fill(medal.rarity.gradient)
                    .frame(width: 140, height: 140)
                    .shadow(color: medal.rarity.color.opacity(0.4), radius: 15, x: 0, y: 8)
                    .rotation3DEffect(
                        .degrees(isRotating ? 360 : 0),
                        axis: (x: 0, y: 1, z: 0)
                    )

                // Inner highlight
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.5), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: 140, height: 140)

                // Icon
                if let iconUrl = medal.iconUrl, let url = URL(string: iconUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 70, height: 70)
                    } placeholder: {
                        categoryIcon
                    }
                } else {
                    categoryIcon
                }

                // Lock overlay
                if !isUnlocked {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 140, height: 140)

                    Image(systemName: "lock.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.8))
                }

                // Legendary particle effect
                if isUnlocked && medal.rarity == .legendary {
                    ForEach(0..<8) { i in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 4, height: 4)
                            .offset(x: 80, y: 0)
                            .rotationEffect(.degrees(Double(i) * 45 + (isRotating ? 360 : 0)))
                            .opacity(0.6)
                    }
                }
            }
            .onAppear {
                if isUnlocked {
                    withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                        isRotating = true
                    }
                }
            }

            // Rarity badge
            HStack(spacing: 8) {
                Circle()
                    .fill(medal.rarity.color)
                    .frame(width: 12, height: 12)

                Text(medal.rarity.displayName)
                    .font(.headline)
                    .foregroundColor(medal.rarity.color)

                Text("•")
                    .foregroundColor(.secondary)

                Text(medal.rarity.materialName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(medal.rarity.color.opacity(0.1))
            .cornerRadius(20)
        }
    }

    private var categoryIcon: some View {
        Image(systemName: medal.category.icon)
            .font(.system(size: 50))
            .foregroundColor(.white)
    }

    // MARK: - Medal Info Section

    private var medalInfoSection: some View {
        VStack(spacing: 12) {
            Text(medal.name)
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            // English name if different
            if medal.nameZh != medal.nameEn {
                Text(Locale.current.language.languageCode?.identifier == "zh" ? medal.nameEn : medal.nameZh)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text(medal.localizedDescription)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Image(systemName: medal.category.icon)
                Text(medal.category.displayName)
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(spacing: 16) {
            if isUnlocked {
                // Unlocked status
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("medal.earned".localized)
                            .font(.headline)
                            .foregroundColor(.green)
                    }

                    if let unlockedAt = unlockedAt {
                        Text(String(format: "medal.unlockedOn".localized, unlockedAt.formatted(date: .long, time: .omitted)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else if let progress = progress, progress.currentValue > 0 {
                // In progress status
                VStack(spacing: 12) {
                    HStack {
                        Text("medal.progress".localized)
                            .font(.headline)
                        Spacer()
                        Text("\(progress.percentageInt)%")
                            .font(.headline)
                            .foregroundColor(medal.rarity.color)
                    }

                    ProgressView(value: progress.percentage)
                        .tint(medal.rarity.color)
                        .scaleEffect(y: 2)

                    Text("\(progress.currentValue) / \(progress.targetValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 5)
            } else {
                // Not started status
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("medal.notStarted".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Requirement Section

    private var requirementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("medal.howToEarn".localized)
                .font(.headline)

            HStack(spacing: 12) {
                Image(systemName: "target")
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(requirementDescription)
                        .font(.body)

                    Text(String(format: "medal.target".localized, medal.unlockThreshold))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    private var requirementDescription: String {
        switch medal.unlockType {
        case .readingDuration:
            return String(format: "medal.requirement.readingDuration".localized, medal.unlockThreshold / 60)
        case .readingStreak:
            return String(format: "medal.requirement.readingStreak".localized, medal.unlockThreshold)
        case .vocabularyCount:
            return String(format: "medal.requirement.vocabularyCount".localized, medal.unlockThreshold)
        case .bookCompleted:
            return String(format: "medal.requirement.bookCompleted".localized, medal.unlockThreshold)
        case .genreReading:
            return String(format: "medal.requirement.genreReading".localized, medal.unlockThreshold / 60)
        case .timeBased:
            return "medal.requirement.timeBased".localized
        case .culturalReading:
            return String(format: "medal.requirement.culturalReading".localized, medal.unlockThreshold / 60)
        case .composite:
            return "medal.requirement.composite".localized
        case .manual:
            return "medal.requirement.manual".localized
        }
    }

    // MARK: - Design Story Section

    private func designStorySection(story: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("medal.designStory".localized)
                .font(.headline)

            Text(story)
                .font(.body)
                .foregroundColor(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Global Stats Section

    private func globalStatsSection(stats: MedalGlobalStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("medal.globalStats".localized)
                .font(.headline)

            HStack(spacing: 20) {
                VStack {
                    Text("\(stats.totalUnlocked)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("medal.globalUnlocked".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                VStack {
                    Text(String(format: "%.1f%%", stats.unlockRate * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("medal.unlockRate".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    // MARK: - Share Section

    private var shareSection: some View {
        Button {
            showShareSheet = true
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("medal.share".localized)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(medal.rarity.gradient)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .sheet(isPresented: $showShareSheet) {
            MedalShareSheet(medal: medal)
        }
    }

    // MARK: - Load Global Stats

    private func loadGlobalStats() async {
        if let detail = await MedalManager.shared.getMedalDetail(medalId: medal.id) {
            self.globalStats = detail.globalStats
        }
    }
}

// MARK: - Medal Share Sheet

struct MedalShareSheet: View {
    let medal: Medal
    @Environment(\.dismiss) private var dismiss
    @State private var shareImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Preview of share card
                MedalShareCard(medal: medal)
                    .padding()

                if let image = shareImage {
                    ShareLink(item: Image(uiImage: image), preview: SharePreview(medal.name, image: Image(uiImage: image))) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("medal.shareNow".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(medal.rarity.gradient)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    ProgressView()
                }

                Spacer()
            }
            .navigationTitle("medal.share".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .task {
                await generateShareImage()
            }
        }
    }

    private func generateShareImage() async {
        let renderer = ImageRenderer(content: MedalShareCard(medal: medal))
        renderer.scale = 3.0
        shareImage = renderer.uiImage
    }
}

// MARK: - Medal Share Card

struct MedalShareCard: View {
    let medal: Medal

    var body: some View {
        VStack(spacing: 24) {
            // Logo placeholder
            HStack {
                Image(systemName: "book.fill")
                    .foregroundColor(.accentColor)
                Text("Readmigo")
                    .font(.headline)
                Spacer()
            }

            // Medal display
            ZStack {
                Circle()
                    .fill(medal.rarity.gradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: medal.rarity.color.opacity(0.4), radius: 10)

                Image(systemName: medal.category.icon)
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // Medal info
            VStack(spacing: 8) {
                Text(medal.name)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 4) {
                    Circle()
                        .fill(medal.rarity.color)
                        .frame(width: 10, height: 10)
                    Text(medal.rarity.displayName)
                        .font(.subheadline)
                        .foregroundColor(medal.rarity.color)
                }

                Text(medal.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Divider()

            // Call to action
            Text("medal.shareInvite".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 20)
    }
}
