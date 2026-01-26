import SwiftUI

struct PreferencesPageView: View {
    let preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.pink)

                    Text("Your Preferences")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding(.top, 32)

                // Reading time preference
                PreferenceCard(
                    icon: preferences.readingTimePreferenceEnum.icon,
                    title: "Reading Style",
                    value: preferences.readingTimePreferenceEnum.localizedName,
                    color: .orange
                )

                // Preferred days
                PreferenceCard(
                    icon: preferences.preferredReadingDaysEnum == .weekend ? "sun.max.fill" : "calendar",
                    title: "Preferred Days",
                    value: preferences.preferredReadingDaysEnum.localizedName,
                    color: .blue
                )

                // Average session
                PreferenceCard(
                    icon: "timer",
                    title: "Average Session",
                    value: "\(preferences.avgSessionMinutes) minutes",
                    color: .green
                )

                // Favorite genres
                if !preferences.favoriteGenres.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Favorite Genres")
                            .font(.headline)

                        ForEach(preferences.favoriteGenres.prefix(3)) { genre in
                            GenreRow(genre: genre)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }

                // AI usage
                if !preferences.aiUsagePreference.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Features Used")
                            .font(.headline)

                        ForEach(preferences.aiUsagePreference.prefix(3)) { usage in
                            AIUsageRow(usage: usage)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                    )
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Preference Card

struct PreferenceCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
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

// MARK: - Genre Row

struct GenreRow: View {
    let genre: GenrePreference

    var body: some View {
        HStack {
            Text(genre.genre)
                .font(.subheadline)

            Spacer()

            Text("\(genre.count) books")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(genre.percentage)%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.purple)
        }
    }
}

// MARK: - AI Usage Row

struct AIUsageRow: View {
    let usage: AIUsagePreference

    var body: some View {
        HStack {
            Text(usage.localizedType)
                .font(.subheadline)

            Spacer()

            Text("\(usage.count) times")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(usage.percentage)%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.blue)
        }
    }
}
