import SwiftUI

/// A view shown when a feature requires login
struct LoginRequiredView: View {
    @EnvironmentObject var authManager: AuthManager
    let feature: String

    private var featureInfo: (icon: String, title: String, description: String) {
        switch feature {
        case "vocabulary":
            return (
                "text.book.closed.fill",
                "auth.required.vocabulary.title".localized,
                "auth.required.vocabulary.description".localized
            )
        case "learning":
            return (
                "brain.head.profile",
                "auth.required.learning.title".localized,
                "auth.required.learning.description".localized
            )
        case "stats":
            return (
                "chart.bar.fill",
                "auth.required.stats.title".localized,
                "auth.required.stats.description".localized
            )
        case "achievements":
            return (
                "medal.fill",
                "auth.required.achievements.title".localized,
                "auth.required.achievements.description".localized
            )
        case "postcards":
            return (
                "photo.on.rectangle",
                "auth.required.postcards.title".localized,
                "auth.required.postcards.description".localized
            )
        case "quotes":
            return (
                "text.quote",
                "auth.required.quotes.title".localized,
                "auth.required.quotes.description".localized
            )
        case "agora":
            return (
                "bubble.left.and.bubble.right.fill",
                "auth.required.agora.title".localized,
                "auth.required.agora.description".localized
            )
        case "chat":
            return (
                "message.fill",
                "auth.required.chat.title".localized,
                "auth.required.chat.description".localized
            )
        default:
            return (
                "person.crop.circle.fill",
                "auth.required.default.title".localized,
                "auth.required.default.description".localized
            )
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Icon with gradient
            Image(systemName: featureInfo.icon)
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandGradientStart, .brandGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            Text(featureInfo.title)
                .font(.title2.bold())
                .foregroundColor(.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text(featureInfo.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Login button
            Button {
                authManager.isGuestMode = false
            } label: {
                Text("auth.required.signIn".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.brandGradientStart, .brandGradientMiddle, .brandGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)

            // Continue browsing
            Button {
                // Dismiss this view - go back
            } label: {
                Text("auth.required.continueBrowsing".localized)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundLight)
    }
}
