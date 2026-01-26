import SwiftUI

struct HighlightsPageView: View {
    let highlights: Highlights

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.yellow)

                    Text("Highlight Moments")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 32)

                // Highlights list
                VStack(spacing: 16) {
                    if let longest = highlights.longestReadingDay {
                        HighlightCard(
                            icon: "clock.badge.checkmark.fill",
                            color: .orange,
                            title: "Longest Reading Day",
                            value: "\(longest.value) minutes",
                            date: longest.formattedDate
                        )
                    }

                    if let night = highlights.latestReadingNight {
                        HighlightCard(
                            icon: "moon.stars.fill",
                            color: .indigo,
                            title: "Late Night Reading",
                            value: night.context ?? "Night owl mode",
                            date: night.formattedDate
                        )
                    }

                    if let notes = highlights.mostNotesDay {
                        HighlightCard(
                            icon: "pencil.line",
                            color: .blue,
                            title: "Most Notes",
                            value: "\(notes.value) notes",
                            date: notes.formattedDate
                        )
                    }

                    if let comments = highlights.mostCommentsDay {
                        HighlightCard(
                            icon: "bubble.left.fill",
                            color: .green,
                            title: "Most Comments",
                            value: "\(comments.value) comments",
                            date: comments.formattedDate
                        )
                    }

                    if let posts = highlights.mostAgoraPostsDay {
                        HighlightCard(
                            icon: "square.grid.2x2.fill",
                            color: .purple,
                            title: "Most Agora Posts",
                            value: "\(posts.value) posts",
                            date: posts.formattedDate
                        )
                    }

                    if let subscription = highlights.firstSubscriptionDay {
                        HighlightCard(
                            icon: "crown.fill",
                            color: .yellow,
                            title: "Became a Pro",
                            value: subscription.planType,
                            date: subscription.dateValue.map { formatDate($0) } ?? subscription.date
                        )
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 50)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Highlight Card

struct HighlightCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let date: String

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}
