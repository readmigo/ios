import SwiftUI

struct BadgeDetailView: View {
    let badge: Badge
    let isEarned: Bool
    let earnedDate: Date?
    let progress: BadgeProgress?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Badge Icon
                    VStack(spacing: 16) {
                        ZStack {
                            // Glow effect
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color(hex: badge.tier.color).opacity(isEarned ? 0.5 : 0.2),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 40,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 160, height: 160)

                            // Badge circle
                            Circle()
                                .fill(tierGradient)
                                .frame(width: 100, height: 100)
                                .shadow(color: Color(hex: badge.tier.color).opacity(0.3), radius: 10)

                            if let iconUrl = badge.iconUrl, let url = URL(string: iconUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                } placeholder: {
                                    Image(systemName: badge.category.icon)
                                        .font(.largeTitle)
                                        .foregroundColor(.white)
                                }
                            } else {
                                Image(systemName: badge.category.icon)
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }

                            // Lock overlay
                            if !isEarned {
                                Circle()
                                    .fill(Color.black.opacity(0.4))
                                    .frame(width: 100, height: 100)

                                Image(systemName: "lock.fill")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        // Tier Badge
                        Text(badge.tier.displayName)
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color(hex: badge.tier.color).opacity(0.2))
                            .foregroundColor(Color(hex: badge.tier.color))
                            .cornerRadius(16)
                    }

                    // Badge Info
                    VStack(spacing: 12) {
                        Text(badge.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(badge.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 4) {
                            Image(systemName: badge.category.icon)
                            Text(badge.category.displayName)
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Status Section
                    VStack(spacing: 16) {
                        if isEarned {
                            // Earned status
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Earned!")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                }

                                if let earnedDate = earnedDate {
                                    Text("Unlocked on \(earnedDate, style: .date)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        } else if let progress = progress {
                            // Progress status
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Progress")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(progress.progressPercent))%")
                                        .font(.headline)
                                        .foregroundColor(Color(hex: badge.tier.color))
                                }

                                ProgressView(value: progress.progressPercent / 100)
                                    .tint(Color(hex: badge.tier.color))
                                    .scaleEffect(y: 2)

                                Text("\(progress.currentValue) / \(progress.targetValue)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                        } else {
                            // Not started
                            VStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("Not yet started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // Requirement Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to Earn")
                            .font(.headline)

                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .foregroundColor(.accentColor)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(badge.requirement.description ?? requirementDescription)
                                    .font(.body)

                                Text("Target: \(badge.requirement.target)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 40)
                }
                .padding(.vertical, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Badge Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var tierGradient: LinearGradient {
        switch badge.tier {
        case .bronze:
            return LinearGradient(
                colors: [Color(hex: "#CD7F32"), Color(hex: "#8B4513")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .silver:
            return LinearGradient(
                colors: [Color(hex: "#C0C0C0"), Color(hex: "#808080")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gold:
            return LinearGradient(
                colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .platinum:
            return LinearGradient(
                colors: [Color(hex: "#E5E4E2"), Color(hex: "#A0A0A0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var requirementDescription: String {
        let type = badge.requirement.type
        let target = badge.requirement.target

        switch type {
        case "books_finished":
            return "Finish \(target) book\(target > 1 ? "s" : "")"
        case "words_learned":
            return "Learn \(target) words"
        case "streak_days":
            return "Maintain a \(target)-day reading streak"
        case "reading_minutes":
            return "Read for \(target) minutes total"
        case "reviews_completed":
            return "Complete \(target) vocabulary reviews"
        default:
            return "Complete the requirement"
        }
    }
}
