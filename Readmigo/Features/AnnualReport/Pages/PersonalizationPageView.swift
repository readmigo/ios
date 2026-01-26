import SwiftUI

struct PersonalizationPageView: View {
    let personalization: Personalization
    let year: Int

    @State private var showShareSheet = false
    @StateObject private var manager = AnnualReportManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // Title badge
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 50))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text(personalization.title)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Badges
                if !personalization.badges.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(personalization.badges, id: \.self) { badge in
                                BadgeView(badge: badge)
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Summary
                VStack(spacing: 16) {
                    Text(localizedSummary)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                }

                // Share button
                Button {
                    Task {
                        if let url = await manager.shareReport(year: year) {
                            showShareSheet = true
                        }
                    }
                } label: {
                    Label("Share Your Year", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 24)
                .disabled(manager.isLoading)

                Spacer(minLength: 50)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let urlString = manager.shareUrl, let url = URL(string: urlString) {
                ShareSheet(items: [url])
            }
        }
    }

    private var localizedSummary: String {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        return personalization.localizedSummary(for: languageCode)
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let badge: String

    var badgeInfo: (icon: String, name: String, color: Color) {
        switch badge {
        case "MARATHON_READER":
            return ("figure.run", "Marathon Reader", .orange)
        case "READING_LEGEND":
            return ("crown.fill", "Reading Legend", .yellow)
        case "BOOK_A_MONTH":
            return ("calendar", "Book a Month", .blue)
        case "BOOK_A_WEEK":
            return ("flame.fill", "Book a Week", .red)
        case "VOCABULARY_MASTER":
            return ("textformat.abc", "Vocabulary Master", .purple)
        case "CONSISTENT_READER":
            return ("chart.line.uptrend.xyaxis", "Consistent Reader", .green)
        default:
            return ("star.fill", badge.replacingOccurrences(of: "_", with: " ").capitalized, .gray)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: badgeInfo.icon)
                .font(.title2)
                .foregroundStyle(badgeInfo.color)
                .frame(width: 50, height: 50)
                .background(badgeInfo.color.opacity(0.15))
                .clipShape(Circle())

            Text(badgeInfo.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}
