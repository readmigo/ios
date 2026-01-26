import SwiftUI

struct InterestsView: View {
    @Binding var selectedInterests: Set<ReadingInterest>
    let onComplete: () -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)

                Text("onboarding.interests.title".localized)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("onboarding.interests.subtitle".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 32)

            // Selection count
            HStack {
                Text("onboarding.interests.selected".localized(with: selectedInterests.count))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if selectedInterests.count > 0 {
                    Button("onboarding.interests.clearAll".localized) {
                        withAnimation {
                            selectedInterests.removeAll()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 24)

            // Interests grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ReadingInterest.allCases) { interest in
                        InterestCard(
                            interest: interest,
                            isSelected: selectedInterests.contains(interest),
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if selectedInterests.contains(interest) {
                                        selectedInterests.remove(interest)
                                    } else {
                                        selectedInterests.insert(interest)
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()

            // Complete button
            VStack(spacing: 12) {
                Button(action: onComplete) {
                    Text(selectedInterests.isEmpty ? "onboarding.interests.skip".localized : "onboarding.interests.complete".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(selectedInterests.isEmpty ? Color.gray : Color.accentColor)
                        .cornerRadius(12)
                }

                if selectedInterests.isEmpty {
                    Text("onboarding.interests.hint".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

struct InterestCard: View {
    let interest: ReadingInterest
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                        .frame(width: 56, height: 56)

                    Image(systemName: interest.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .primary)
                }

                VStack(spacing: 2) {
                    Text(interest.displayName)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)

                    Text(interest.localizedName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
