import SwiftUI

struct GoalSettingView: View {
    @Binding var dailyGoalMinutes: Int
    let onContinue: () -> Void

    private let goalOptions = [5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("Set your daily reading goal")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Consistent practice is key to improvement.\nHow much time can you read each day?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Goal display
            VStack(spacing: 8) {
                Text("\(dailyGoalMinutes)")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)

                Text("minutes per day")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 24)

            // Goal options grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(goalOptions, id: \.self) { minutes in
                    GoalOptionButton(
                        minutes: minutes,
                        isSelected: dailyGoalMinutes == minutes,
                        onTap: { dailyGoalMinutes = minutes }
                    )
                }
            }
            .padding(.horizontal, 24)

            // Recommendation
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text(recommendationText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)

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

    private var recommendationText: String {
        switch dailyGoalMinutes {
        case 0..<10:
            return "A great start! Even short sessions help build habits."
        case 10..<20:
            return "Perfect for building a sustainable reading habit."
        case 20..<30:
            return "Recommended for steady vocabulary growth."
        case 30..<45:
            return "Excellent commitment! You'll see fast progress."
        default:
            return "Ambitious goal! Remember, consistency matters most."
        }
    }
}

struct GoalOptionButton: View {
    let minutes: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(minutes)")
                    .font(.title2.bold())
                    .foregroundColor(isSelected ? .white : .primary)

                Text("min")
                    .font(.caption)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}
