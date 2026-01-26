import SwiftUI

// MARK: - Medal Card View

struct MedalCardView: View {
    let medal: Medal
    var isUnlocked: Bool = false
    var unlockedAt: Date?
    var progress: MedalProgress?
    var onTap: (() -> Void)?

    @State private var isAnimating = false

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: 12) {
                // Medal Icon with 3D-like effect
                ZStack {
                    // Outer glow for unlocked medals
                    if isUnlocked {
                        Circle()
                            .fill(medal.rarity.glowColor)
                            .frame(width: 80, height: 80)
                            .blur(radius: 10)
                            .opacity(isAnimating ? 0.8 : 0.4)
                    }

                    // Medal circle with gradient
                    Circle()
                        .fill(medal.rarity.gradient)
                        .frame(width: 64, height: 64)
                        .shadow(color: medal.rarity.color.opacity(0.4), radius: 5, x: 0, y: 3)

                    // Inner highlight
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.4), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: 64, height: 64)

                    // Icon or image
                    if let iconUrl = medal.iconUrl, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                        } placeholder: {
                            categoryIcon
                        }
                    } else {
                        categoryIcon
                    }

                    // Lock overlay for unearned medals
                    if !isUnlocked {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 64, height: 64)

                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.title3)
                    }
                }

                // Medal name
                Text(medal.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                // Rarity badge
                Text(medal.rarity.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(medal.rarity.color.opacity(0.2))
                    .foregroundColor(medal.rarity.color)
                    .cornerRadius(4)

                // Progress bar (if not unlocked and has progress)
                if !isUnlocked, let progress = progress {
                    VStack(spacing: 4) {
                        ProgressView(value: progress.percentage)
                            .tint(medal.rarity.color)
                            .frame(height: 4)

                        Text("\(progress.currentValue)/\(progress.targetValue)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Unlock date (if unlocked)
                if isUnlocked, let unlockedAt = unlockedAt {
                    Text(unlockedAt, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            if isUnlocked && medal.rarity == .legendary {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }
        }
    }

    private var categoryIcon: some View {
        Image(systemName: medal.category.icon)
            .font(.title2)
            .foregroundColor(.white)
    }
}

// MARK: - Compact Medal Card

struct CompactMedalCard: View {
    let medal: Medal
    var isUnlocked: Bool = false
    var progress: MedalProgress?
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(medal.rarity.gradient)
                        .frame(width: 44, height: 44)

                    if let iconUrl = medal.iconUrl, let url = URL(string: iconUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 24, height: 24)
                        } placeholder: {
                            Image(systemName: medal.category.icon)
                                .font(.body)
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: medal.category.icon)
                            .font(.body)
                            .foregroundColor(.white)
                    }

                    if !isUnlocked {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 44, height: 44)

                        Image(systemName: "lock.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.caption)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(medal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isUnlocked ? .primary : .secondary)

                        Spacer()

                        Text(medal.rarity.displayName)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(medal.rarity.color.opacity(0.2))
                            .foregroundColor(medal.rarity.color)
                            .cornerRadius(4)
                    }

                    Text(medal.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if !isUnlocked, let progress = progress {
                        HStack {
                            ProgressView(value: progress.percentage)
                                .tint(medal.rarity.color)

                            Text("\(progress.percentageInt)%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medal Progress Row

struct MedalProgressRow: View {
    let medal: Medal
    let progress: MedalProgress
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(medal.rarity.color.opacity(0.2))
                        .frame(width: 48, height: 48)

                    Image(systemName: medal.category.icon)
                        .foregroundColor(medal.rarity.color)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(medal.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Spacer()

                        Text("\(progress.percentageInt)%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(medal.rarity.color)
                    }

                    ProgressView(value: progress.percentage)
                        .tint(medal.rarity.color)

                    Text("\(progress.currentValue) / \(progress.targetValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medal Category Chip

struct MedalCategoryChip: View {
    let category: MedalCategory?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                    Text(category.displayName)
                        .font(.subheadline)
                } else {
                    Image(systemName: "square.grid.2x2")
                        .font(.caption)
                    Text("common.all".localized)
                        .font(.subheadline)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Medal Rarity Filter

struct MedalRarityFilter: View {
    @Binding var selectedRarity: MedalRarity?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All rarities
                Button {
                    selectedRarity = nil
                } label: {
                    Text("common.all".localized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedRarity == nil ? Color.accentColor : Color(.systemGray6))
                        .foregroundColor(selectedRarity == nil ? .white : .primary)
                        .cornerRadius(16)
                }

                // Individual rarities
                ForEach(MedalRarity.allCases, id: \.self) { rarity in
                    Button {
                        selectedRarity = rarity
                    } label: {
                        Text(rarity.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedRarity == rarity ? rarity.color : rarity.color.opacity(0.2))
                            .foregroundColor(selectedRarity == rarity ? .white : rarity.color)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
