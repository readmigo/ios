import SwiftUI

struct LevelAssessmentView: View {
    @Binding var selectedLevel: EnglishLevel
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("What's your English level?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("This helps us recommend books\nat the right difficulty for you")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Level options
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(EnglishLevel.allCases, id: \.self) { level in
                        LevelOptionCard(
                            level: level,
                            isSelected: selectedLevel == level,
                            onTap: { selectedLevel = level }
                        )
                    }
                }
                .padding(.horizontal, 24)
            }

            Spacer()

            // Continue button
            Button(action: onContinue) {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.accentColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct LevelOptionCard: View {
    let level: EnglishLevel
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Level indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Text(levelEmoji)
                        .font(.title2)
                }

                // Level info
                VStack(alignment: .leading, spacing: 4) {
                    Text(level.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .gray.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var levelEmoji: String {
        switch level {
        case .beginner: return "🌱"
        case .elementary: return "🌿"
        case .intermediate: return "🌳"
        case .upperIntermediate: return "🌲"
        case .advanced: return "🏔️"
        }
    }
}
