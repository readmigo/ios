import Foundation

/// Response from the /config/client endpoint
struct ClientConfig: Codable {
    let environment: String
    let version: String
    let features: FeatureConfig

    struct FeatureConfig: Codable {
        let chineseContent: ChineseContentConfig
    }

    struct ChineseContentConfig: Codable {
        let enabled: Bool
        let allowedLanguages: [String]
        let comingSoonMessage: String?
    }
}

/// Manages app configuration fetched from the server
@MainActor
class AppConfigManager: ObservableObject {
    static let shared = AppConfigManager()

    private let configCacheKey = "cached_client_config"
    private let lastFetchKey = "config_last_fetch_time"
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    @Published private(set) var config: ClientConfig?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    // Feature flag convenience accessors
    var isChineseContentEnabled: Bool {
        config?.features.chineseContent.enabled ?? false
    }

    var allowedLanguages: [String] {
        config?.features.chineseContent.allowedLanguages ?? ["en"]
    }

    var chineseContentComingSoonMessage: String? {
        config?.features.chineseContent.comingSoonMessage
    }

    private init() {
        // Load cached config on init
        loadCachedConfig()

        // Listen for environment changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEnvironmentChange),
            name: .environmentDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEnvironmentChange(_ notification: Notification) {
        // Update APIClient base URL when environment changes
        if let newEnvironment = notification.object as? AppEnvironment {
            LoggingService.shared.info(.app, "Environment changed to \(newEnvironment.displayName)", component: "AppConfigManager")
            Task {
                // Update API base URL
                await APIClient.shared.updateBaseURL(newEnvironment.apiBaseURL)

                // Clear all caches (this is important for proper environment isolation)
                await EnvironmentManager.shared.clearAllCaches()
            }
        }

        // Clear local config cache and refetch from new environment
        clearCache()
        Task {
            await fetchConfig()
        }
    }

    /// Fetch configuration from the server
    func fetchConfig() async {
        guard !isLoading else { return }

        // Check if cache is still valid
        if let lastFetch = UserDefaults.standard.object(forKey: lastFetchKey) as? Date,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration,
           config != nil {
            return
        }

        isLoading = true
        error = nil

        do {
            let fetchedConfig: ClientConfig = try await APIClient.shared.request(
                endpoint: "/config/client",
                method: .get
            )

            self.config = fetchedConfig
            cacheConfig(fetchedConfig)
            UserDefaults.standard.set(Date(), forKey: lastFetchKey)
        } catch {
            self.error = error
            // If fetch fails, keep using cached config
            if self.config == nil {
                loadCachedConfig()
            }
        }

        isLoading = false
    }

    /// Force refresh the configuration
    func refreshConfig() async {
        clearCache()
        await fetchConfig()
    }

    /// Check if a specific language is allowed
    func isLanguageAllowed(_ language: String) -> Bool {
        allowedLanguages.contains(language)
    }

    /// Check if Chinese content should be shown
    func shouldShowChineseContent() -> Bool {
        isChineseContentEnabled && isLanguageAllowed("zh")
    }

    // MARK: - Cache Management

    private func cacheConfig(_ config: ClientConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            UserDefaults.standard.set(data, forKey: configCacheKey)
        } catch {
            print("Failed to cache config: \(error)")
        }
    }

    private func loadCachedConfig() {
        guard let data = UserDefaults.standard.data(forKey: configCacheKey) else {
            return
        }

        do {
            config = try JSONDecoder().decode(ClientConfig.self, from: data)
        } catch {
            print("Failed to load cached config: \(error)")
        }
    }

    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: configCacheKey)
        UserDefaults.standard.removeObject(forKey: lastFetchKey)
        config = nil
    }
}

// MARK: - API Endpoints Extension

extension APIEndpoints {
    static let configClient = "/config/client"
    static let configClientAuthenticated = "/config/client/authenticated"
}
