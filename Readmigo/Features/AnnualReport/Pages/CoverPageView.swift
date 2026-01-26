import SwiftUI

struct CoverPageView: View {
    let report: AnnualReport
    let year: Int

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Year badge
            Text("\(String(year))")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            VStack(spacing: 8) {
                Text("Your Year in Reading")
                    .font(.title)
                    .fontWeight(.semibold)

                Text(report.personalization.title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Quick stats
            HStack(spacing: 32) {
                CoverStatBadge(
                    value: "\(report.readingOverview.finishedBooks)",
                    label: "Books"
                )

                CoverStatBadge(
                    value: "\(report.readingOverview.totalReadingHours)",
                    label: "Hours"
                )

                CoverStatBadge(
                    value: "\(report.socialRanking.topPercentile)%",
                    label: "Top"
                )
            }

            Spacer()

            // Swipe hint
            VStack(spacing: 4) {
                Image(systemName: "chevron.compact.left")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .symbolEffect(.pulse)

                Text("Swipe to explore")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 32)
        }
        .padding()
    }
}

// MARK: - Cover Stat Badge

private struct CoverStatBadge: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Preview Data

extension AnnualReport {
    static var preview: AnnualReport {
        AnnualReport(
            id: "preview",
            year: 2024,
            status: "COMPLETED",
            generatedAt: Date(),
            readingOverview: ReadingOverview(
                totalBooks: 15,
                finishedBooks: 12,
                totalReadingMinutes: 3600,
                totalPages: 4500,
                completionRate: 80,
                booksDetail: []
            ),
            highlights: Highlights(
                longestReadingDay: HighlightMoment(date: "2024-03-15", value: 180, context: nil),
                latestReadingNight: HighlightMoment(date: "2024-06-20", value: 1440, context: "23:45"),
                mostNotesDay: nil,
                mostCommentsDay: nil,
                mostAgoraPostsDay: nil,
                mostFeedbackDay: nil,
                firstSubscriptionDay: nil
            ),
            socialRanking: SocialRanking(
                readingTimePercentile: 85,
                booksReadPercentile: 90,
                vocabularyPercentile: 75
            ),
            preferences: Preferences(
                readingTimePreference: "NIGHT_OWL",
                preferredReadingDays: "WEEKEND",
                avgSessionMinutes: 45,
                favoriteGenres: [
                    GenrePreference(genre: "Fiction", count: 8, percentage: 53),
                    GenrePreference(genre: "Self-Help", count: 4, percentage: 27)
                ],
                aiUsagePreference: [
                    AIUsagePreference(type: "EXPLAIN", count: 150, percentage: 60),
                    AIUsagePreference(type: "TRANSLATE", count: 80, percentage: 32)
                ]
            ),
            personalization: Personalization(
                badges: ["MARATHON_READER", "BOOK_A_MONTH"],
                title: "Bookworm",
                summary: "In 2024, you spent 60 hours reading 12 books and learned 500 new words. Keep up the great work!",
                summaryLocalized: nil
            ),
            shareCardUrl: nil
        )
    }
}
