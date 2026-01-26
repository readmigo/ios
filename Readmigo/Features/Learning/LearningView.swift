import SwiftUI

struct LearningView: View {
    @StateObject private var vocabularyManager = VocabularyManager.shared
    @State private var showingReview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's Stats
                    TodayStatsCard(stats: vocabularyManager.stats)

                    // Quick Actions
                    QuickActionsSection(
                        dueWords: vocabularyManager.reviewWords.count,
                        onReviewTap: { showingReview = true }
                    )

                    // Learning Progress
                    if let stats = vocabularyManager.stats {
                        LearningProgressSection(stats: stats)
                    }

                    // Recent Words
                    RecentWordsSection(words: Array(vocabularyManager.words.prefix(5)))
                }
                .padding()
            }
            .navigationTitle("Learn")
            .elegantRefreshable {
                await vocabularyManager.fetchStats()
                await vocabularyManager.fetchReviewWords()
            }
            .fullScreenCover(isPresented: $showingReview) {
                ReviewSessionView()
            }
        }
        .task {
            await vocabularyManager.fetchStats()
            await vocabularyManager.fetchReviewWords()
            await vocabularyManager.fetchVocabulary()
        }
    }
}

// MARK: - Today's Stats Card

struct TodayStatsCard: View {
    let stats: VocabularyStats?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.headline)

                    if let streak = stats?.streakDays, streak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                            Text("\(streak) day streak")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                Text(Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 20) {
                TodayStatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(stats?.todayReviewed ?? 0)",
                    label: "Reviewed",
                    color: .green
                )

                TodayStatItem(
                    icon: "clock.fill",
                    value: "\(stats?.dueForReview ?? 0)",
                    label: "Due",
                    color: stats?.dueForReview ?? 0 > 0 ? .orange : .gray
                )

                TodayStatItem(
                    icon: "star.fill",
                    value: "\(stats?.masteredWords ?? 0)",
                    label: "Mastered",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct TodayStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quick Actions

struct QuickActionsSection: View {
    let dueWords: Int
    let onReviewTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                // Review Button
                Button(action: onReviewTap) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Review")
                                .fontWeight(.semibold)

                            if dueWords > 0 {
                                Text("\(dueWords) words due")
                                    .font(.caption)
                                    .opacity(0.8)
                            } else {
                                Text("All caught up!")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(dueWords > 0 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(dueWords == 0)
            }
        }
    }
}

// MARK: - Learning Progress

struct LearningProgressSection: View {
    let stats: VocabularyStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Learning Progress")
                .font(.headline)

            VStack(spacing: 16) {
                // Progress Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Vocabulary Mastery")
                            .font(.subheadline)

                        Spacer()

                        Text("\(masteryPercentage)%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .cornerRadius(4)

                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .green],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * CGFloat(masteryPercentage) / 100)
                                .cornerRadius(4)
                        }
                    }
                    .frame(height: 8)
                }

                // Breakdown
                HStack(spacing: 20) {
                    ProgressItem(
                        label: "New",
                        count: stats.newWords,
                        color: .gray
                    )

                    ProgressItem(
                        label: "Learning",
                        count: stats.learningWords,
                        color: .orange
                    )

                    ProgressItem(
                        label: "Mastered",
                        count: stats.masteredWords,
                        color: .green
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }

    private var masteryPercentage: Int {
        guard stats.totalWords > 0 else { return 0 }
        return Int(Double(stats.masteredWords) / Double(stats.totalWords) * 100)
    }
}

struct ProgressItem: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text("\(count)")
                .font(.headline)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recent Words

struct RecentWordsSection: View {
    let words: [VocabularyWord]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Words")
                    .font(.headline)

                Spacer()

                NavigationLink(destination: VocabularyView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }

            if words.isEmpty {
                Text("No words added yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(words) { word in
                        HStack {
                            Text(word.word)
                                .fontWeight(.medium)

                            Spacer()

                            MasteryBadge(repetitions: word.repetitions)
                        }
                        .padding(.vertical, 12)

                        if word.id != words.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
            }
        }
    }
}
