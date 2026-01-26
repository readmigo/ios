import Foundation
import SwiftUI

// MARK: - Version Check Response Model

struct VersionCheckResponse: Codable {
    let currentVersion: String
    let minSupportedVersion: String
    let forceUpdateRequired: Bool
    let updateAvailable: Bool
    let releaseNotes: String?
    let releaseNotesZh: String?
    let storeUrl: String?
    let buildNumber: Int
    let releaseDate: String
}

// MARK: - Version Manager

@MainActor
final class VersionManager: ObservableObject {
    static let shared = VersionManager()

    // MARK: - Published Properties

    @Published private(set) var isChecking = false
    @Published private(set) var forceUpdateRequired = false
    @Published private(set) var updateAvailable = false
    @Published private(set) var currentVersion: String?
    @Published private(set) var releaseNotes: String?
    @Published private(set) var storeUrl: String?
    @Published private(set) var lastCheckTime: Date?
    @Published private(set) var checkError: Error?

    // MARK: - Private Properties

    private let checkInterval: TimeInterval = 3600 // 1 hour
    private let userDefaults = UserDefaults.standard
    private let lastCheckKey = "VersionManager.lastCheckTime"
    private let cachedResponseKey = "VersionManager.cachedResponse"

    // MARK: - Computed Properties

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var shouldShowUpdateBanner: Bool {
        updateAvailable && !forceUpdateRequired
    }

    // MARK: - Initialization

    private init() {
        loadCachedState()
    }

    // MARK: - Public Methods

    /// Check app version against server
    /// - Parameter force: Force check even if recently checked
    func checkVersion(force: Bool = false) async {
        // Skip if recently checked (unless forced)
        if !force && !shouldCheck() {
            return
        }

        isChecking = true
        checkError = nil

        do {
            let response = try await performVersionCheck()
            handleVersionCheckResponse(response)
            cacheResponse(response)
            lastCheckTime = Date()
            userDefaults.set(Date(), forKey: lastCheckKey)
        } catch {
            checkError = error
            LoggingService.shared.error(
                .network,
                "Version check failed: \(error.localizedDescription)"
            )
        }

        isChecking = false
    }

    /// Open App Store for update
    func openAppStore() {
        let urlString = storeUrl ?? defaultAppStoreUrl
        guard let url = URL(string: urlString) else {
            return
        }

        UIApplication.shared.open(url)
    }

    /// Get localized release notes based on current locale
    var localizedReleaseNotes: String? {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        if languageCode.hasPrefix("zh") {
            return releaseNotes // Use Chinese notes if available
        }
        return releaseNotes
    }

    // MARK: - Private Methods

    private func shouldCheck() -> Bool {
        guard let lastCheck = lastCheckTime ?? userDefaults.object(forKey: lastCheckKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(lastCheck) > checkInterval
    }

    private func performVersionCheck() async throws -> VersionCheckResponse {
        let baseURL = await APIClient.shared.baseURL
        var request = URLRequest(url: URL(string: "\(baseURL)\(APIEndpoints.versionCheck)")!)
        request.httpMethod = "GET"
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(buildNumber, forHTTPHeaderField: "X-Build-Number")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(VersionCheckResponse.self, from: data)
    }

    private func handleVersionCheckResponse(_ response: VersionCheckResponse) {
        currentVersion = response.currentVersion
        forceUpdateRequired = response.forceUpdateRequired
        updateAvailable = response.updateAvailable
        storeUrl = response.storeUrl

        // Use localized release notes
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        if languageCode.hasPrefix("zh"), let zhNotes = response.releaseNotesZh {
            releaseNotes = zhNotes
        } else {
            releaseNotes = response.releaseNotes
        }

        if forceUpdateRequired {
            LoggingService.shared.warning(
                .app,
                "Force update required: \(appVersion) < \(response.minSupportedVersion)"
            )
        } else if updateAvailable {
            LoggingService.shared.info(
                .app,
                "Update available: \(appVersion) → \(response.currentVersion)"
            )
        }
    }

    private func loadCachedState() {
        lastCheckTime = userDefaults.object(forKey: lastCheckKey) as? Date

        if let data = userDefaults.data(forKey: cachedResponseKey),
           let response = try? JSONDecoder().decode(VersionCheckResponse.self, from: data) {
            handleVersionCheckResponse(response)
        }
    }

    private func cacheResponse(_ response: VersionCheckResponse) {
        if let data = try? JSONEncoder().encode(response) {
            userDefaults.set(data, forKey: cachedResponseKey)
        }
    }

    private var defaultAppStoreUrl: String {
        // Update with actual App Store ID after release
        "https://apps.apple.com/app/readmigo/id123456789"
    }
}
