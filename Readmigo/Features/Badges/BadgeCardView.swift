import SwiftUI

struct BadgeCardView: View {
    let badge: Badge
    var isEarned: Bool = false
    var earnedDate: Date?
    var progress: BadgeProgress?
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 12) {
                // Badge Icon
                ZStack {
                    Circle()
                        .fill(tierGradient)
                        .frame(width: 64, height: 64)

                    if let iconUrl = badge.iconUrl, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                        } placeholder: {
                            Image(systemName: badge.category.icon)
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: badge.category.icon)
                            .font(.title2)
                            .foregroundColor(.white)
                    }

                    if !isEarned {
                        Circle()
                            .fill(Color.black.opacity(0.4))
                            .frame(width: 64, height: 64)

                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                    }
                }

                // Badge Name
                Text(badge.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isEarned ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Tier Badge
                Text(badge.tier.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(badge.tier.adaptiveColor.opacity(0.2))
                    .foregroundColor(badge.tier.adaptiveColor)
                    .cornerRadius(4)

                // Progress Bar (if not earned)
                if !isEarned, let progress = progress {
                    VStack(spacing: 4) {
                        ProgressView(value: progress.progressPercent / 100)
                            .tint(badge.tier.adaptiveColor)

                        Text("\(progress.currentValue)/\(progress.targetValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Earned Date
                if isEarned, let earnedDate = earnedDate {
                    Text(earnedDate, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var tierGradient: LinearGradient {
        LinearGradient(
            colors: [badge.tier.adaptiveColor, badge.tier.secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Compact Badge Card

struct CompactBadgeCard: View {
    let badge: Badge
    var isEarned: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(badge.tier.adaptiveColor.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: badge.category.icon)
                    .foregroundColor(badge.tier.adaptiveColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(badge.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isEarned ? .primary : .secondary)

                Text(badge.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isEarned {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

