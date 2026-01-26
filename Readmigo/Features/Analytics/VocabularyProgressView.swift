import SwiftUI
import Charts

struct VocabularyProgressView: View {
    @StateObject private var manager = AnalyticsManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let progress = manager.vocabularyProgress {
                    // Overview Ring
                    OverviewRingSection(progress: progress)

                    // Distribution Chart
                    DistributionSection(progress: progress)

                    // Weekly History
                    WeeklyHistorySection(history: progress.weeklyHistory)

                    // Stats Grid
                    StatsGridSection(progress: progress)
                } else if manager.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    EmptyStateView(
                        icon: "text.book.closed",
                        title: "No Vocabulary Data",
                        message: "Start learning words to track your progress!"
                    )
                }

                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Vocabulary Progress")
        .task {
            await manager.fetchVocabularyProgress()
        }
    }
}

// MARK: - Overview Ring Section

struct OverviewRingSection: View {
    let progress: VocabularyProgress

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress.retentionRate / 100)
                    .stroke(
                        AngularGradient(
                            colors: [.green, .blue, .purple],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text("\(Int(progress.retentionRate))%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Retention Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 32) {
                VStack {
                    Text("\(progress.totalWords)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total Words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text("\(progress.masteredWords)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Mastered")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack {
                    Text(String(format: "%.1f", progress.averageReviewsPerDay))
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Reviews/Day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
    }
}

// MARK: - Distribution Section

struct DistributionSection: View {
    let progress: VocabularyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Word Distribution")
                .font(.headline)

            Chart {
                SectorMark(
                    angle: .value("Count", progress.masteredWords),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.green)
                .annotation(position: .overlay) {
                    if progress.masteredWords > 0 {
                        Text("\(progress.masteredWords)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }

                SectorMark(
                    angle: .value("Count", progress.learningWords),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.orange)
                .annotation(position: .overlay) {
                    if progress.learningWords > 0 {
                        Text("\(progress.learningWords)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }

                SectorMark(
                    angle: .value("Count", progress.newWords),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(.purple)
                .annotation(position: .overlay) {
                    if progress.newWords > 0 {
                        Text("\(progress.newWords)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
            }
            .frame(height: 200)

            // Legend
            HStack(spacing: 24) {
                LegendItem(color: .green, label: "Mastered")
                LegendItem(color: .orange, label: "Learning")
                LegendItem(color: .purple, label: "New")
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Weekly History Section

struct WeeklyHistorySection: View {
    let history: [DailyVocabStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week")
                .font(.headline)

            if history.isEmpty {
                Text("No data for this week")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Chart(history) { stat in
                    BarMark(
                        x: .value("Date", formatDate(stat.date)),
                        y: .value("Words", stat.wordsLearned)
                    )
                    .foregroundStyle(.blue.opacity(0.7))

                    BarMark(
                        x: .value("Date", formatDate(stat.date)),
                        y: .value("Reviews", stat.wordsReviewed)
                    )
                    .foregroundStyle(.green.opacity(0.7))
                }
                .frame(height: 180)
                .chartLegend(position: .bottom)

                HStack(spacing: 24) {
                    LegendItem(color: .blue, label: "Learned")
                    LegendItem(color: .green, label: "Reviewed")
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

// MARK: - Stats Grid Section

struct StatsGridSection: View {
    let progress: VocabularyProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Summary")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                SummaryCard(
                    icon: "brain.head.profile",
                    title: "Total Words",
                    value: "\(progress.totalWords)",
                    color: .blue
                )

                SummaryCard(
                    icon: "checkmark.circle.fill",
                    title: "Mastery Rate",
                    value: "\(masteryPercent)%",
                    color: .green
                )

                SummaryCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Avg Reviews",
                    value: String(format: "%.1f/day", progress.averageReviewsPerDay),
                    color: .orange
                )

                SummaryCard(
                    icon: "sparkles",
                    title: "New This Week",
                    value: "\(weeklyNewWords)",
                    color: .purple
                )
            }
        }
    }

    private var masteryPercent: Int {
        guard progress.totalWords > 0 else { return 0 }
        return Int((Double(progress.masteredWords) / Double(progress.totalWords)) * 100)
    }

    private var weeklyNewWords: Int {
        progress.weeklyHistory.reduce(0) { $0 + $1.wordsLearned }
    }
}

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
