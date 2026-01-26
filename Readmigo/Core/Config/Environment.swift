import SwiftUI

/// App environment enumeration for multi-environment support
/// - production: V1 production (api.readmigo.app → readmigo-v1)
/// - staging: Staging environment
/// - debugging: Debug environment
/// - local: Local development
enum AppEnvironment: String, CaseIterable, Identifiable {
    case local = "local"
    case debugging = "debugging"
    case staging = "staging"
    case production = "production"

    var id: String { rawValue }

    /// API base URL for each environment
    /// Production uses multi-version co-existence strategy (supports up to 10 versions):
    /// - V1 (1.x.x): v1.api.readmigo.app → readmigo-v1
    /// - V2 (2.x.x): v2.api.readmigo.app → readmigo-v2
    /// - V3 (3.x.x): v3.api.readmigo.app → readmigo-v3
    /// - ...
    /// - Latest: api.readmigo.app → latest version
    var apiBaseURL: String {
        switch self {
        case .local:
            return "http://localhost:3000/api/v1"
        case .debugging:
            return "https://readmigo-debug.fly.dev/api/v1"
        case .staging:
            return "https://readmigo-staging.fly.dev/api/v1"
        case .production:
            // Get app major version to determine which backend to use
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            let majorVersion = appVersion.split(separator: ".").first.flatMap { Int($0) } ?? 1

            // Multi-version co-existence: each major version has its own subdomain
            // Example: v1.x.x → v1.api.readmigo.app, v2.x.x → v2.api.readmigo.app
            let versionedDomain = "v\(majorVersion).api.readmigo.app"
            return "https://\(versionedDomain)/api/v\(majorVersion)"
        }
    }

    /// Display name for UI
    var displayName: String {
        switch self {
        case .local:
            return "Local Dev"
        case .debugging:
            return "Debugging"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }

    /// Short display name for badge
    var shortName: String {
        switch self {
        case .local:
            return "DEV"
        case .debugging:
            return "DBG"
        case .staging:
            return "STG"
        case .production:
            return "PROD"
        }
    }

    /// Color for environment indicator
    var color: Color {
        switch self {
        case .local:
            return .orange
        case .debugging:
            return .blue
        case .staging:
            return .purple
        case .production:
            return .green
        }
    }

    /// Whether this environment should show debug features
    var isDebugEnvironment: Bool {
        switch self {
        case .local, .debugging, .staging:
            return true
        case .production:
            return false
        }
    }
}

/// Manages the current app environment
@MainActor
class EnvironmentManager: ObservableObject {
    static let shared = EnvironmentManager()

    private let storageKey = "selected_environment"

    @Published private(set) var current: AppEnvironment
    @Published private(set) var isSwitching = false

    private init() {
        #if DEBUG
        // Debug builds: default to local, allow switching via EnvironmentSwitcher
        if let savedEnv = UserDefaults.standard.string(forKey: storageKey),
           let env = AppEnvironment(rawValue: savedEnv) {
            self.current = env
        } else {
            self.current = .local
        }
        #else
        // Release builds always use production
        self.current = .production
        #endif
    }

    /// Switch to a different environment (debug builds only)
    /// This will sign out the user and clear all caches since data is environment-specific
    func switchEnvironment(to environment: AppEnvironment) {
        #if DEBUG
        guard environment != current else { return }

        isSwitching = true

        // Store the new environment
        current = environment
        UserDefaults.standard.set(environment.rawValue, forKey: storageKey)

        // Post notification for components that need to react
        // Components should:
        // 1. Update their base URLs (APIClient)
        // 2. Clear their caches (AppConfigManager, etc.)
        // 3. Sign out (AuthManager)
        NotificationCenter.default.post(
            name: .environmentDidChange,
            object: environment
        )

        // Reset switching state after a short delay to allow UI to update
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            isSwitching = false
        }
        #endif
    }

    /// Clear all app caches and data for the current environment
    /// Call this when you need a clean slate
    func clearAllCaches() async {
        #if DEBUG
        // Use the unified CacheManager to clear all caches
        await CacheManager.shared.clearAllCaches()

        // Clear additional manager-specific caches
        CharacterMapManager.shared.clearCache()
        TimelineManager.shared.clearCache()
        PostcardsManager.shared.clearCache()
        AnnualReportManager.shared.clearCache()

        // Clear URL cache
        URLCache.shared.removeAllCachedResponses()

        LoggingService.shared.info(.app, "All caches cleared for environment switch", component: "EnvironmentManager")
        #endif
    }

    /// Check if environment switching is allowed
    var canSwitchEnvironment: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Get the API base URL for the current environment
    var apiBaseURL: String {
        current.apiBaseURL
    }

    /// Check if we're in a production environment
    var isProduction: Bool {
        current == .production
    }

    /// Check if we're in a debug-capable environment
    var isDebugEnvironment: Bool {
        current.isDebugEnvironment
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let environmentDidChange = Notification.Name("environmentDidChange")
}
