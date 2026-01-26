import SwiftUI

struct RankingPageView: View {
    let ranking: SocialRanking

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.yellow)

                Text("Your Ranking")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("See how you compare to other readers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Ranking bars
            VStack(spacing: 24) {
                RankingBar(
                    icon: "clock.fill",
                    label: "Reading Time",
                    percentile: ranking.readingTimePercentile,
                    color: .orange
                )

                RankingBar(
                    icon: "book.fill",
                    label: "Books Read",
                    percentile: ranking.booksReadPercentile,
                    color: .blue
                )

                RankingBar(
                    icon: "textformat.abc",
                    label: "Vocabulary",
                    percentile: ranking.vocabularyPercentile,
                    color: .purple
                )
            }
            .padding(.horizontal, 24)

            // Summary text
            VStack(spacing: 8) {
                Text("You beat")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(ranking.topPercentile)%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("of all readers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Ranking Bar

struct RankingBar: View {
    let icon: String
    let label: String
    let percentile: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)

                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text("Top \(100 - percentile)%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))

                    // Fill
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(percentile) / 100)
                }
            }
            .frame(height: 12)
        }
    }
}
