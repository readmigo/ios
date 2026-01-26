import Foundation

/// Application information model
struct AppInfo {
    /// App version (e.g., "1.0.0")
    let version: String
    /// Build number (e.g., "1")
    let build: String
    /// Bundle identifier
    let bundleIdentifier: String

    /// Get current app information from Bundle
    static var current: AppInfo {
        let info = Bundle.main.infoDictionary ?? [:]
        return AppInfo(
            version: info["CFBundleShortVersionString"] as? String ?? "Unknown",
            build: info["CFBundleVersion"] as? String ?? "Unknown",
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "Unknown"
        )
    }

    /// Full version string (e.g., "1.0.0 (1)")
    var fullVersionString: String {
        "\(version) (\(build))"
    }
}
