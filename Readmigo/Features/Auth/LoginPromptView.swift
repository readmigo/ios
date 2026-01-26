import SwiftUI

/// A view that prompts the user to login for a specific feature
struct LoginPromptView: View {
    @EnvironmentObject var authManager: AuthManager
    let feature: String
    let onDismiss: () -> Void

    private var featureDescription: String {
        switch feature {
        case "library":
            return "auth.loginPrompt.library".localized
        case "bookmark":
            return "auth.loginPrompt.bookmark".localized
        case "highlight":
            return "auth.loginPrompt.highlight".localized
        case "vocabulary":
            return "auth.loginPrompt.vocabulary".localized
        case "learning":
            return "auth.loginPrompt.learning".localized
        case "like":
            return "auth.loginPrompt.like".localized
        case "postcard":
            return "auth.loginPrompt.postcard".localized
        case "chat":
            return "auth.loginPrompt.chat".localized
        case "ai":
            return "auth.loginPrompt.ai".localized
        case "achievements":
            return "auth.loginPrompt.achievements".localized
        case "stats":
            return "auth.loginPrompt.stats".localized
        case "download":
            return "auth.loginPrompt.download".localized
        default:
            return "auth.loginPrompt.default".localized
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "person.circle")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.brandGradientStart, .brandGradientEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Title
            Text("auth.loginPrompt.title".localized)
                .font(.title2.bold())
                .foregroundColor(.textPrimary)

            // Description
            Text(featureDescription)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Buttons
            VStack(spacing: 12) {
                // Login button
                Button {
                    onDismiss()
                    // Navigate to auth view - the ContentView will handle this
                    authManager.isGuestMode = false
                } label: {
                    Text("auth.loginPrompt.logIn".localized)
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

                // Later button
                Button {
                    onDismiss()
                } label: {
                    Text("auth.loginPrompt.maybeLater".localized)
                        .font(.headline)
                        .foregroundColor(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 32)
        .background(Color.backgroundCard)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 24)
    }
}

/// View modifier for login prompt
struct LoginPromptModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager
    @Binding var isPresented: Bool
    let feature: String

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                LoginPromptView(feature: feature) {
                    isPresented = false
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }
}

/// Global login prompt modifier that listens to AuthManager
struct GlobalLoginPromptModifier: ViewModifier {
    @EnvironmentObject var authManager: AuthManager

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $authManager.showLoginPrompt) {
                LoginPromptView(feature: authManager.loginPromptFeature) {
                    authManager.dismissLoginPrompt()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    /// Add a login prompt sheet for a specific feature
    func loginPrompt(isPresented: Binding<Bool>, feature: String) -> some View {
        modifier(LoginPromptModifier(isPresented: isPresented, feature: feature))
    }

    /// Add global login prompt that responds to AuthManager.showLoginPrompt
    func globalLoginPrompt() -> some View {
        modifier(GlobalLoginPromptModifier())
    }
}
