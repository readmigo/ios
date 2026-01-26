import Foundation
import AuthenticationServices
import UIKit
import GoogleSignIn

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var isNewUser = false
    /// Start in guest mode to prevent brief AuthView flash during initialization
    /// Will be updated by checkExistingSession if user has valid session
    @Published var isGuestMode = true
    @Published var showLoginPrompt = false
    @Published var loginPromptFeature: String = ""

    /// Callback to execute after successful login
    var onLoginSuccess: (() -> Void)?

    private let keychain = KeychainManager.shared

    var accessToken: String? {
        keychain.get("accessToken")
    }

    private var refreshToken: String? {
        keychain.get("refreshToken")
    }

    private init() {
        LoggingService.shared.info(.auth, "AuthManager initialized", component: "AuthManager")

        // Listen for environment changes - need to sign out when switching environments
        // since auth tokens are environment-specific
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnvironmentChange),
            name: .environmentDidChange,
            object: nil
        )

        Task {
            await checkExistingSession()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEnvironmentChange(_ notification: Notification) {
        // Sign out when environment changes - tokens are not valid across environments
        LoggingService.shared.info(.auth, "Environment changed, signing out user", component: "AuthManager")
        Task {
            await signOut()
        }
    }

    private func checkExistingSession() async {
        guard accessToken != nil else {
            // Already in guest mode by default, just log
            LoggingService.shared.debug(.auth, "No existing session found, staying in guest mode", component: "AuthManager")
            return
        }

        LoggingService.shared.debug(.auth, "Checking existing session", component: "AuthManager")
        isLoading = true
        defer { isLoading = false }

        do {
            let user: User = try await APIClient.shared.request(endpoint: APIEndpoints.userMe)
            self.currentUser = user
            self.isAuthenticated = true
            self.isGuestMode = false  // Exit guest mode when authenticated
            LoggingService.shared.info(.auth, "Session restored for user: \(user.email ?? "unknown")", component: "AuthManager")
        } catch {
            LoggingService.shared.warning(.auth, "Session expired or invalid, clearing session", component: "AuthManager")
            await signOut()
        }
    }

    // MARK: - Apple Sign In

    func signInWithApple(authorization: ASAuthorization) async {
        LoggingService.shared.info(.auth, "Apple Sign In started", component: "AuthManager")

        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8),
              let authorizationCodeData = appleIDCredential.authorizationCode,
              let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
            self.error = "Failed to get Apple credentials"
            LoggingService.shared.error(.auth, "Failed to extract Apple credentials", component: "AuthManager")
            return
        }

        LoggingService.shared.debug(.auth, "Apple credentials extracted, userIdentifier: \(appleIDCredential.user.prefix(8))...", component: "AuthManager")

        var fullName: String?
        if let givenName = appleIDCredential.fullName?.givenName,
           let familyName = appleIDCredential.fullName?.familyName {
            fullName = "\(givenName) \(familyName)"
        }

        isLoading = true
        error = nil

        do {
            let request = AppleAuthRequest(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName
            )

            LoggingService.shared.debug(.auth, "Sending Apple auth request to backend", component: "AuthManager")

            let response: AuthResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authApple,
                method: .post,
                body: request
            )

            LoggingService.shared.info(.auth, "Apple Sign In successful, user: \(response.user.email ?? "no email"), isNewUser: \(response.isNewUser)", component: "AuthManager")
            await handleAuthResponse(response)
        } catch {
            LoggingService.shared.error(.auth, "Apple Sign In failed: \(error.localizedDescription)", component: "AuthManager")
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Google Sign In

    func signInWithGoogle(idToken: String) async {
        LoggingService.shared.info(.auth, "Google Sign In started", component: "AuthManager")
        isLoading = true
        error = nil

        do {
            let request = GoogleAuthRequest(idToken: idToken)
            let response: AuthResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authGoogle,
                method: .post,
                body: request
            )

            LoggingService.shared.info(.auth, "Google Sign In successful, user: \(response.user.email ?? "no email"), isNewUser: \(response.isNewUser)", component: "AuthManager")
            await handleAuthResponse(response)
        } catch {
            LoggingService.shared.error(.auth, "Google Sign In failed: \(error.localizedDescription)", component: "AuthManager")
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Initiates Google Sign In flow
    func initiateGoogleSignIn() {
        LoggingService.shared.debug(.auth, "Initiating Google Sign In flow", component: "AuthManager")

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            LoggingService.shared.error(.auth, "Cannot find root view controller for Google Sign In", component: "AuthManager")
            self.error = "Cannot find root view controller"
            return
        }

        isLoading = true
        error = nil

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, signInError in
            Task { @MainActor in
                guard let self = self else { return }

                if let signInError = signInError {
                    self.isLoading = false
                    // Check if user cancelled - don't show error for cancellation
                    let nsError = signInError as NSError
                    if nsError.domain == "com.google.GIDSignIn" && nsError.code == -5 {
                        LoggingService.shared.debug(.auth, "Google Sign In cancelled by user", component: "AuthManager")
                        return
                    }
                    LoggingService.shared.error(.auth, "Google Sign In UI error: \(signInError.localizedDescription)", component: "AuthManager")
                    self.error = signInError.localizedDescription
                    return
                }

                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self.isLoading = false
                    LoggingService.shared.error(.auth, "Failed to get Google ID token", component: "AuthManager")
                    self.error = "Failed to get Google ID token"
                    return
                }

                LoggingService.shared.debug(.auth, "Google ID token obtained", component: "AuthManager")
                await self.signInWithGoogle(idToken: idToken)
            }
        }
    }

    // MARK: - Email Authentication

    func register(email: String, password: String, displayName: String?) async {
        LoggingService.shared.info(.auth, "Email registration started", component: "AuthManager")
        isLoading = true
        error = nil

        do {
            let request = EmailRegisterRequest(email: email, password: password, displayName: displayName)
            let response: AuthResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authRegister,
                method: .post,
                body: request
            )

            LoggingService.shared.info(.auth, "Email registration successful, user: \(response.user.email ?? "no email")", component: "AuthManager")
            await handleAuthResponse(response)
        } catch {
            LoggingService.shared.error(.auth, "Email registration failed: \(error.localizedDescription)", component: "AuthManager")
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func login(email: String, password: String) async {
        LoggingService.shared.info(.auth, "Email login started", component: "AuthManager")
        isLoading = true
        error = nil

        do {
            let request = EmailLoginRequest(email: email, password: password)
            let response: AuthResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authLogin,
                method: .post,
                body: request
            )

            LoggingService.shared.info(.auth, "Email login successful, user: \(response.user.email ?? "no email")", component: "AuthManager")
            await handleAuthResponse(response)
        } catch {
            LoggingService.shared.error(.auth, "Email login failed: \(error.localizedDescription)", component: "AuthManager")
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func forgotPassword(email: String) async -> Bool {
        LoggingService.shared.info(.auth, "Password reset requested", component: "AuthManager")
        isLoading = true
        error = nil

        do {
            let request = ForgotPasswordRequest(email: email)
            let _: SuccessResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authForgotPassword,
                method: .post,
                body: request
            )

            LoggingService.shared.info(.auth, "Password reset email sent", component: "AuthManager")
            isLoading = false
            return true
        } catch {
            LoggingService.shared.error(.auth, "Password reset request failed: \(error.localizedDescription)", component: "AuthManager")
            self.error = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Token Refresh

    func refreshAccessToken() async -> Bool {
        guard let refreshToken = refreshToken else {
            LoggingService.shared.debug(.auth, "No refresh token available", component: "AuthManager")
            return false
        }

        LoggingService.shared.debug(.auth, "Attempting token refresh", component: "AuthManager")

        do {
            let request = RefreshTokenRequest(refreshToken: refreshToken)
            let response: TokenResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.authRefresh,
                method: .post,
                body: request
            )

            keychain.set(response.accessToken, forKey: "accessToken")
            keychain.set(response.refreshToken, forKey: "refreshToken")
            LoggingService.shared.info(.auth, "Token refresh successful", component: "AuthManager")
            return true
        } catch {
            LoggingService.shared.warning(.auth, "Token refresh failed: \(error.localizedDescription)", component: "AuthManager")
            await signOut()
            return false
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        LoggingService.shared.info(.auth, "User signing out", component: "AuthManager")
        keychain.delete("accessToken")
        keychain.delete("refreshToken")
        currentUser = nil
        isAuthenticated = false
        isNewUser = false
        isGuestMode = true  // Return to guest mode after sign out
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        LoggingService.shared.debug(.auth, "Sign out completed, session cleared", component: "AuthManager")
    }

    // MARK: - Guest Mode

    /// Enter guest mode without logging in
    func enterGuestMode() {
        LoggingService.shared.info(.auth, "Entering guest mode", component: "AuthManager")
        isGuestMode = true
    }

    /// Check if login is required for a feature, show prompt if needed
    /// - Parameters:
    ///   - feature: The feature name to display in prompt
    ///   - action: The action to execute if logged in, or after successful login
    /// - Returns: true if user is logged in and can proceed immediately
    @discardableResult
    func requireLogin(for feature: String, action: (() -> Void)? = nil) -> Bool {
        if isAuthenticated {
            action?()
            return true
        } else {
            loginPromptFeature = feature
            onLoginSuccess = action
            showLoginPrompt = true
            return false
        }
    }

    /// Dismiss login prompt
    func dismissLoginPrompt() {
        showLoginPrompt = false
        loginPromptFeature = ""
        onLoginSuccess = nil
    }

    // MARK: - Delete Account

    func deleteAccount() async throws {
        LoggingService.shared.info(.auth, "Account deletion requested", component: "AuthManager")
        isLoading = true
        defer { isLoading = false }

        // Call backend to delete account
        try await APIClient.shared.request(
            endpoint: APIEndpoints.deleteAccount,
            method: .delete
        ) as EmptyResponse

        LoggingService.shared.info(.auth, "Account deleted successfully", component: "AuthManager")
        // Clear local data
        await signOut()
    }

    // MARK: - Update Profile

    func updateProfile(displayName: String?, englishLevel: EnglishLevel?, dailyGoalMinutes: Int?) async throws {
        LoggingService.shared.debug(.auth, "Updating user profile", component: "AuthManager")

        let updateRequest = UserUpdateRequest(
            displayName: displayName,
            englishLevel: englishLevel?.rawValue,
            dailyGoalMinutes: dailyGoalMinutes
        )

        let user: User = try await APIClient.shared.request(
            endpoint: APIEndpoints.userMe,
            method: .patch,
            body: updateRequest
        )

        self.currentUser = user
        LoggingService.shared.info(.auth, "Profile updated successfully", component: "AuthManager")
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        isNewUser = false
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func resetOnboardingStatus() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    // MARK: - Private Helpers

    private func handleAuthResponse(_ response: AuthResponse) async {
        keychain.set(response.accessToken, forKey: "accessToken")
        keychain.set(response.refreshToken, forKey: "refreshToken")
        currentUser = response.user
        isAuthenticated = true
        isNewUser = response.isNewUser
        isGuestMode = false  // Exit guest mode when authenticated

        // Merge browsing history to cloud library
        await mergeGuestBrowsingHistory()

        // Execute any pending login success callback
        if let callback = onLoginSuccess {
            callback()
            onLoginSuccess = nil
        }

        // Dismiss login prompt if showing
        showLoginPrompt = false
        loginPromptFeature = ""
    }

    /// Merge guest browsing history to cloud after login
    private func mergeGuestBrowsingHistory() async {
        let browsingHistory = BrowsingHistoryManager.shared.localHistory
        guard !browsingHistory.isEmpty else {
            LoggingService.shared.debug(.auth, "No browsing history to merge", component: "AuthManager")
            return
        }

        LoggingService.shared.info(.auth, "Merging \(browsingHistory.count) browsed books to cloud", component: "AuthManager")

        // Merge local browsing history to cloud (browsing history is separate from library)
        await BrowsingHistoryManager.shared.mergeAfterLogin()

        LoggingService.shared.info(.auth, "Browsing history merged to cloud", component: "AuthManager")
    }
}

// MARK: - Request/Response Models

struct AppleAuthRequest: Codable {
    let identityToken: String
    let authorizationCode: String
    let fullName: String?
    // Device info
    let deviceId: String?
    let platform: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?

    init(identityToken: String, authorizationCode: String, fullName: String?) {
        self.identityToken = identityToken
        self.authorizationCode = authorizationCode
        self.fullName = fullName
        // Add device info
        let deviceInfo = AboutDeviceInfo.current
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString
        self.platform = "IOS"
        self.deviceModel = deviceInfo.model
        self.osVersion = deviceInfo.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

struct GoogleAuthRequest: Codable {
    let idToken: String
    // Device info
    let deviceId: String?
    let platform: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?

    init(idToken: String) {
        self.idToken = idToken
        // Add device info
        let deviceInfo = AboutDeviceInfo.current
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString
        self.platform = "IOS"
        self.deviceModel = deviceInfo.model
        self.osVersion = deviceInfo.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
}

struct UserUpdateRequest: Codable {
    let displayName: String?
    let englishLevel: String?
    let dailyGoalMinutes: Int?
}

struct EmailRegisterRequest: Codable {
    let email: String
    let password: String
    let displayName: String?
    // Device info
    let deviceId: String?
    let platform: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?

    init(email: String, password: String, displayName: String?) {
        self.email = email
        self.password = password
        self.displayName = displayName
        // Add device info
        let deviceInfo = AboutDeviceInfo.current
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString
        self.platform = "IOS"
        self.deviceModel = deviceInfo.model
        self.osVersion = deviceInfo.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

struct EmailLoginRequest: Codable {
    let email: String
    let password: String
    // Device info
    let deviceId: String?
    let platform: String?
    let deviceModel: String?
    let osVersion: String?
    let appVersion: String?

    init(email: String, password: String) {
        self.email = email
        self.password = password
        // Add device info
        let deviceInfo = AboutDeviceInfo.current
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString
        self.platform = "IOS"
        self.deviceModel = deviceInfo.model
        self.osVersion = deviceInfo.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

struct ForgotPasswordRequest: Codable {
    let email: String
}
