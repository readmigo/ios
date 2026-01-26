import Foundation

enum AuthError: LocalizedError {
    case networkError
    case appleSignInFailed
    case googleSignInFailed
    case googleSignInNotConfigured
    case tokenExpired
    case invalidCredentials
    case userNotFound
    case accountDeleted
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkError:
            return String(localized: "auth.error.network", defaultValue: "Network connection failed. Please check your internet and try again.")
        case .appleSignInFailed:
            return String(localized: "auth.error.apple_failed", defaultValue: "Apple Sign In failed. Please try again.")
        case .googleSignInFailed:
            return String(localized: "auth.error.google_failed", defaultValue: "Google Sign In failed. Please try again.")
        case .googleSignInNotConfigured:
            return String(localized: "auth.error.google_not_configured", defaultValue: "Google Sign In is not configured. Please use Apple Sign In.")
        case .tokenExpired:
            return String(localized: "auth.error.token_expired", defaultValue: "Your session has expired. Please sign in again.")
        case .invalidCredentials:
            return String(localized: "auth.error.invalid_credentials", defaultValue: "Invalid credentials. Please try again.")
        case .userNotFound:
            return String(localized: "auth.error.user_not_found", defaultValue: "User not found. Please sign up first.")
        case .accountDeleted:
            return String(localized: "auth.error.account_deleted", defaultValue: "This account has been deleted.")
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return String(localized: "auth.recovery.network", defaultValue: "Check your internet connection and try again.")
        case .appleSignInFailed, .googleSignInFailed:
            return String(localized: "auth.recovery.signin_failed", defaultValue: "Please try signing in again or use a different method.")
        case .tokenExpired:
            return String(localized: "auth.recovery.token_expired", defaultValue: "Please sign in again to continue.")
        default:
            return nil
        }
    }
}

// MARK: - Localized Strings Extension

extension String {
    // Authentication
    static let authErrorNetwork = String(localized: "auth.error.network")
    static let authErrorAppleFailed = String(localized: "auth.error.apple_failed")
    static let authErrorGoogleFailed = String(localized: "auth.error.google_failed")
    static let authErrorTokenExpired = String(localized: "auth.error.token_expired")

    // Onboarding
    static let onboardingWelcomeTitle = String(localized: "onboarding.welcome.title", defaultValue: "Welcome to Readmigo!")
    static let onboardingWelcomeSubtitle = String(localized: "onboarding.welcome.subtitle", defaultValue: "Learn English naturally by reading great literature with AI assistance")

    static let onboardingLevelTitle = String(localized: "onboarding.level.title", defaultValue: "What's your English level?")
    static let onboardingLevelSubtitle = String(localized: "onboarding.level.subtitle", defaultValue: "This helps us recommend books at the right difficulty for you")

    static let onboardingGoalTitle = String(localized: "onboarding.goal.title", defaultValue: "Set your daily reading goal")
    static let onboardingGoalSubtitle = String(localized: "onboarding.goal.subtitle", defaultValue: "Consistent practice is key to improvement. How much time can you read each day?")

    static let onboardingInterestsTitle = String(localized: "onboarding.interests.title", defaultValue: "What do you like to read?")
    static let onboardingInterestsSubtitle = String(localized: "onboarding.interests.subtitle", defaultValue: "Select your interests to get personalized book recommendations")

    // Account
    static let accountSignOut = String(localized: "account.sign_out", defaultValue: "Sign Out")
    static let accountDeleteAccount = String(localized: "account.delete_account", defaultValue: "Delete Account")
    static let accountDeleteConfirmTitle = String(localized: "account.delete_confirm.title", defaultValue: "Delete Account?")
    static let accountDeleteConfirmMessage = String(localized: "account.delete_confirm.message", defaultValue: "This action cannot be undone. All your data will be permanently deleted.")
}
