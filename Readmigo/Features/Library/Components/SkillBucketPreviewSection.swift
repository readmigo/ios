import SwiftUI

// MARK: - Data Models

/// Skill dimension for the bucket chart
struct SkillDimension: Codable, Identifiable {
    let id: String
    let name: String            // e.g., "词汇量", "语法", "句式", "文化背景"
    let nameEn: String          // e.g., "Vocabulary", "Grammar", "Sentence", "Culture"
    let level: String           // CEFR level: A1, A2, B1, B2, C1, C2
    let description: String     // Brief description of requirement
    let sampleWords: [String]   // Sample vocabulary for this dimension

    var localizedName: String {
        LocaleHelper.isChineseLocale ? name : nameEn
    }

    /// Convert CEFR level to numeric value (1-6)
    var levelValue: Int {
        switch level.uppercased() {
        case "A1": return 1
        case "A2": return 2
        case "B1": return 3
        case "B2": return 4
        case "C1": return 5
        case "C2": return 6
        default: return 3
        }
    }
}

/// Book readiness data containing skill requirements
struct BookReadinessPreview: Codable {
    let bookId: String
    let suggestedLevel: String                  // Overall suggested level
    let skillDimensions: [SkillDimension]       // All dimensions with their data
    let shortestBoard: String                   // ID of the weakest dimension
    let tip: String                             // Advice for the reader
    let tipEn: String                           // English version

    var localizedTip: String {
        LocaleHelper.isChineseLocale ? tip : tipEn
    }
}

// MARK: - Skill Bucket Preview Section

/// Section displaying skill bucket chart with dimension vocabulary preview
struct SkillBucketPreviewSection: View {
    let bookId: String

    @State private var readinessData: BookReadinessPreview?
    @State private var isLoading = true
    @State private var isExpanded = true

    // Template data for display when API data is not available
    private let templateDimensions: [SkillDimension] = [
        SkillDimension(
            id: "vocabulary",
            name: "词汇量",
            nameEn: "Vocabulary",
            level: "B2",
            description: "需认识约 {wordCount} 个不同词汇",
            sampleWords: ["{word1}", "{word2}", "{word3}", "{word4}", "{word5}"]
        ),
        SkillDimension(
            id: "grammar",
            name: "语法",
            nameEn: "Grammar",
            level: "B1",
            description: "基础语法即可，少量复杂结构",
            sampleWords: ["{grammar1}", "{grammar2}", "{grammar3}"]
        ),
        SkillDimension(
            id: "sentence",
            name: "句式",
            nameEn: "Sentence",
            level: "B2",
            description: "平均句长 {avgLength} 词，需适应长句",
            sampleWords: ["{pattern1}", "{pattern2}", "{pattern3}"]
        ),
        SkillDimension(
            id: "culture",
            name: "文化背景",
            nameEn: "Culture",
            level: "C1",
            description: "需了解{era}社会背景",
            sampleWords: ["{culture1}", "{culture2}", "{culture3}", "{culture4}"]
        ),
        SkillDimension(
            id: "overall",
            name: "整体难度",
            nameEn: "Overall",
            level: "B2",
            description: "适合{levelDesc}英语学习者",
            sampleWords: []
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with expand/collapse
            headerView

            if isExpanded {
                // Content
                if isLoading {
                    loadingView
                } else if let data = readinessData {
                    contentView(data)
                } else {
                    templateView
                }
            }
        }
        .background(
            Group {
                #if DEBUG
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            LoggingService.shared.debug(.books, "DEBUG_LAYOUT: SkillBucket width: \(geo.size.width)", component: "SkillBucketPreviewSection")
                        }
                        .onChange(of: geo.size.width) { _, newWidth in
                            LoggingService.shared.debug(.books, "DEBUG_LAYOUT: SkillBucket width changed to: \(newWidth)", component: "SkillBucketPreviewSection")
                        }
                }
                #else
                Color.clear
                #endif
            }
        )
        .task {
            await loadReadinessData()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)

                Text("skillBucket.title".localized)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("common.loading".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Content View (with real data)

    private func contentView(_ data: BookReadinessPreview) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bucket Chart Visualization
            bucketChartView(dimensions: data.skillDimensions, shortestBoard: data.shortestBoard)

            // Dimension Cards with vocabulary
            ForEach(data.skillDimensions) { dimension in
                dimensionCard(dimension, isShortestBoard: dimension.id == data.shortestBoard)
            }

            // Tip
            tipView(data.localizedTip)

            // Suggested Level Badge
            suggestedLevelBadge(data.suggestedLevel)
        }
    }

    // MARK: - Template View (placeholder for preview)

    private var templateView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Bucket Chart Visualization
            bucketChartView(dimensions: templateDimensions, shortestBoard: "culture")

            // Dimension Cards
            ForEach(templateDimensions) { dimension in
                dimensionCard(dimension, isShortestBoard: dimension.id == "culture")
            }

            // Placeholder tip
            tipView("skillBucket.tipPlaceholder".localized)

            // Suggested Level Badge
            suggestedLevelBadge("B2")
        }
    }

    // MARK: - Bucket Chart Visualization

    private func bucketChartView(dimensions: [SkillDimension], shortestBoard: String) -> some View {
        VStack(spacing: 8) {
            // Bar chart
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(dimensions.filter { $0.id != "overall" }) { dimension in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(dimension.id == shortestBoard ? Color.orange : Color.accentColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: CGFloat(dimension.levelValue) * 15)

                        // Level label
                        Text(dimension.level)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(dimension.id == shortestBoard ? .orange : .secondary)

                        // Dimension name
                        Text(dimension.localizedName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("skillBucket.shortestBoard".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                    Text("skillBucket.otherDimensions".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Dimension Card

    private func dimensionCard(_ dimension: SkillDimension, isShortestBoard: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(dimension.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(dimension.level)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(isShortestBoard ? Color.orange : Color.accentColor)
                    .cornerRadius(4)

                if isShortestBoard {
                    Text("skillBucket.biggestChallenge".localized)
                        .font(.caption2)
                        .foregroundColor(.orange)
                }

                Spacer()
            }

            // Description
            Text(dimension.description)
                .font(.caption)
                .foregroundColor(.secondary)

            // Sample Words (Vocabulary slots)
            if !dimension.sampleWords.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(dimension.sampleWords, id: \.self) { word in
                        Text(word)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isShortestBoard ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Tip View

    private func tipView(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)

            Text(tip)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(8)
    }

    // MARK: - Suggested Level Badge

    private func suggestedLevelBadge(_ level: String) -> some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                Text("skillBucket.suggestedLevel".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(level)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Load Data

    private func loadReadinessData() async {
        isLoading = true

        do {
            // TODO: Replace with actual API endpoint when available
            // let endpoint = APIEndpoints.bookReadiness(bookId)
            // readinessData = try await APIClient.shared.request(endpoint: endpoint)

            // For now, simulate loading delay and use nil (will show template)
            try await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run {
                self.readinessData = nil
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
            LoggingService.shared.debug(.books, "Failed to load readiness data: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        SkillBucketPreviewSection(bookId: "test-book-id")
            .padding()
    }
}
