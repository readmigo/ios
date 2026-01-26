import SwiftUI

struct ReadingOverviewPageView: View {
    let overview: ReadingOverview

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)

                    Text("Reading Overview")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 32)

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    OverviewStatCard(
                        icon: "book.closed.fill",
                        value: "\(overview.totalBooks)",
                        label: "Books Started",
                        color: .blue
                    )

                    OverviewStatCard(
                        icon: "checkmark.circle.fill",
                        value: "\(overview.finishedBooks)",
                        label: "Books Finished",
                        color: .green
                    )

                    OverviewStatCard(
                        icon: "clock.fill",
                        value: overview.formattedReadingTime,
                        label: "Total Reading Time",
                        color: .orange
                    )

                    OverviewStatCard(
                        icon: "doc.text.fill",
                        value: "\(overview.totalPages)",
                        label: "Pages Read",
                        color: .purple
                    )
                }
                .padding(.horizontal)

                // Completion rate
                VStack(spacing: 12) {
                    Text("Completion Rate")
                        .font(.headline)

                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                        Circle()
                            .trim(from: 0, to: Double(overview.completionRate) / 100)
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Text("\(overview.completionRate)%")
                                .font(.system(size: 32, weight: .bold, design: .rounded))

                            Text("\(overview.finishedBooks)/\(overview.totalBooks)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 150, height: 150)
                }
                .padding(.vertical)

                Spacer()
            }
        }
    }
}

// MARK: - Overview Stat Card

struct OverviewStatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}
