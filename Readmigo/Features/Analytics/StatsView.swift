import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = AnalyticsManager.shared
    @State private var selectedPeriod = "week"

    var body: some View {
        NavigationStack {
            if !authManager.isAuthenticated {
                LoginRequiredView(feature: "stats")
            } else {
            ScrollView {
                VStack(spacing: 24) {
                    // Overview Cards
                    if let stats = manager.overviewStats {
                        OverviewSection(stats: stats)
                    }

                    // Reading Trend Chart
                    if let trend = manager.readingTrend {
                        ReadingTrendSection(trend: trend)
                    }

                    // Vocabulary Progress
                    if let vocabProgress = manager.vocabularyProgress {
                        VocabularySection(progress: vocabProgress)
                    }

                    // Reading Progress
                    if let readingProgress = manager.readingProgress {
                        ReadingProgressSection(progress: readingProgress)
                    }

                    // Daily Stats
                    if !manager.dailyStats.isEmpty {
                        DailyStatsSection(stats: manager.dailyStats)
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("stats.title".localized)
            .elegantRefreshable {
                await manager.refreshAll()
            }
            .overlay {
                if manager.isLoading && manager.overviewStats == nil {
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

// MARK: - Overview Section

struct OverviewSection: View {
    let stats: OverviewStats

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.overview".localized)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "stats.readingTime".localized,
                    value: formatMinutes(stats.totalReadingMinutes),
                    icon: "clock.fill",
                    color: .blue
                )

                StatCard(
                    title: "stats.booksRead".localized,
                    value: "\(stats.totalBooksRead)",
                    icon: "book.closed.fill",
                    color: .green
                )

                StatCard(
                    title: "stats.wordsLearned".localized,
                    value: "\(stats.totalWordsLearned)",
                    icon: "text.book.closed.fill",
                    color: .purple
                )

                StatCard(
                    title: "stats.currentStreak".localized,
                    value: "stats.streakDays".localized(with: stats.currentStreak),
                    icon: "flame.fill",
                    color: .orange
                )
            }

            // Today's Progress
            HStack(spacing: 16) {
                TodayStatCard(
                    title: "stats.today".localized,
                    value: "stats.minutes".localized(with: stats.todayMinutes),
                    icon: "sun.max.fill"
                )

                TodayStatCard(
                    title: "stats.thisWeek".localized,
                    value: "stats.minutes".localized(with: stats.weeklyMinutes),
                    icon: "calendar"
                )

                TodayStatCard(
                    title: "stats.thisMonth".localized,
                    value: "stats.minutes".localized(with: stats.monthlyMinutes),
                    icon: "calendar.badge.clock"
                )
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        if hours > 0 {
            return "\(hours)h \(minutes % 60)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

// MARK: - Today Stat Card

struct TodayStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Reading Trend Section

struct ReadingTrendSection: View {
    let trend: ReadingTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("stats.readingTrend".localized)
                    .font(.headline)
                Spacer()
                TrendBadge(trend: trend.trend, percentChange: trend.percentChange)
            }

            if !trend.data.isEmpty {
                Chart(trend.data) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Minutes", point.value)
                    )
                    .foregroundStyle(Color.accentColor)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Minutes", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.accentColor.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5))
                }
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("stats.average".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("stats.minPerDay".localized(with: Int(trend.averageMinutes)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("stats.total".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("stats.minutes".localized(with: trend.totalMinutes))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Trend Badge

struct TrendBadge: View {
    let trend: TrendDirection
    let percentChange: Double?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
            if let change = percentChange {
                Text("\(Int(abs(change)))%")
            }
        }
        .font(.caption)
        .fontWeight(.medium)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor.opacity(0.1))
        .foregroundColor(trendColor)
        .cornerRadius(8)
    }

    private var trendColor: Color {
        switch trend {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

// MARK: - Vocabulary Section

struct VocabularySection: View {
    let progress: VocabularyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.vocabularyProgress".localized)
                .font(.headline)

            // Progress Ring
            HStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: progress.retentionRate / 100)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    VStack {
                        Text("\(Int(progress.retentionRate))%")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("stats.retention".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    VocabStatRow(label: "stats.vocab.total".localized, value: "\(progress.totalWords)", color: .blue)
                    VocabStatRow(label: "stats.vocab.mastered".localized, value: "\(progress.masteredWords)", color: .green)
                    VocabStatRow(label: "stats.vocab.learning".localized, value: "\(progress.learningWords)", color: .orange)
                    VocabStatRow(label: "stats.vocab.new".localized, value: "\(progress.newWords)", color: .purple)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct VocabStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Reading Progress Section

struct ReadingProgressSection: View {
    let progress: ReadingProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.currentlyReading".localized)
                .font(.headline)

            if progress.currentlyReading.isEmpty {
                Text("stats.noBooksInProgress".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(progress.currentlyReading) { book in
                    BookProgressRow(book: book)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct BookProgressRow: View {
    let book: BookProgress

    var body: some View {
        HStack(spacing: 12) {
            if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                }
                .frame(width: 40, height: 56)
                .cornerRadius(4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                ProgressView(value: book.progressPercent / 100)
                    .tint(.accentColor)

                Text("stats.percentComplete".localized(with: Int(book.progressPercent)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Daily Stats Section

struct DailyStatsSection: View {
    let stats: [DailyStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.dailyBreakdown".localized)
                .font(.headline)

            ForEach(stats.prefix(7)) { stat in
                DailyStatRow(stat: stat)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct DailyStatRow: View {
    let stat: DailyStats

    var body: some View {
        HStack {
            Text(formattedDate)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Spacer()

            HStack(spacing: 16) {
                Label("\(stat.readingMinutes)m", systemImage: "clock")
                Label("\(stat.wordsLearned)", systemImage: "text.book.closed")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var formattedDate: String {
        guard let date = stat.dateValue else { return stat.date }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}
