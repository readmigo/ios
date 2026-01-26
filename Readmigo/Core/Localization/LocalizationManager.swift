import Foundation
import SwiftUI

/// Supported languages in the app
enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .chineseSimplified:
            return "简体中文"
        case .chineseTraditional:
            return "繁體中文"
        }
    }

    var flag: String {
        switch self {
        case .english:
            return "🇺🇸"
        case .chineseSimplified:
            return "🇨🇳"
        case .chineseTraditional:
            return "🇹🇼"
        }
    }

    /// Convert to Accept-Language header value
    var acceptLanguageValue: String {
        switch self {
        case .english:
            return "en"
        case .chineseSimplified:
            return "zh-Hans"
        case .chineseTraditional:
            return "zh-Hant"
        }
    }
}

/// Manages app localization and language preferences
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    private let userDefaultsKey = "preferredLanguage"

    /// Currently selected language
    @Published var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: userDefaultsKey)
            updateBundleLanguage()
            notifyLanguageChange()
        }
    }

    /// Whether the user has manually selected a language (vs using system default)
    @Published var hasManualSelection: Bool

    private init() {
        // Check for stored preference
        if let stored = UserDefaults.standard.string(forKey: userDefaultsKey),
           let language = AppLanguage(rawValue: stored) {
            self.currentLanguage = language
            self.hasManualSelection = true
        } else {
            // Use system language
            self.currentLanguage = Self.detectSystemLanguage()
            self.hasManualSelection = false
        }

        updateBundleLanguage()
    }

    /// Detect the system language and map to supported language
    private static func detectSystemLanguage() -> AppLanguage {
        let preferredLanguages = Locale.preferredLanguages

        for language in preferredLanguages {
            if language.hasPrefix("zh-Hans") || language.hasPrefix("zh-CN") {
                return .chineseSimplified
            } else if language.hasPrefix("zh-Hant") || language.hasPrefix("zh-TW") || language.hasPrefix("zh-HK") {
                return .chineseTraditional
            } else if language.hasPrefix("zh") {
                // Generic Chinese defaults to Simplified
                return .chineseSimplified
            } else if language.hasPrefix("en") {
                return .english
            }
        }

        // Default to English if no match
        return .english
    }

    /// Set language manually
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        hasManualSelection = true
    }

    /// Reset to system language
    func resetToSystemLanguage() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        currentLanguage = Self.detectSystemLanguage()
        hasManualSelection = false
    }

    /// Get the Accept-Language header value for API requests
    var acceptLanguageHeader: String {
        currentLanguage.acceptLanguageValue
    }

    /// Check if current language is Chinese (either simplified or traditional)
    var isChinese: Bool {
        currentLanguage == .chineseSimplified || currentLanguage == .chineseTraditional
    }

    /// Update the bundle language for localization
    private func updateBundleLanguage() {
        // Set the AppleLanguages to force localization
        UserDefaults.standard.set([currentLanguage.rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    /// Notify other parts of the app about language change
    private func notifyLanguageChange() {
        NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
    }

    /// Sync language preference to server
    func syncToServer() async {
        // This will be called when user changes language
        // to sync the preference to their account
        do {
            try await APIClient.shared.updateLanguagePreference(currentLanguage.rawValue)
        } catch {
            print("[LocalizationManager] Failed to sync language to server: \(error)")
        }
    }

    /// Load language preference from server (after login)
    func loadFromServer(preferredLanguage: String?) {
        guard let languageCode = preferredLanguage,
              let language = AppLanguage(rawValue: languageCode) else {
            return
        }

        // Only update if user hasn't made a manual selection locally
        if !hasManualSelection {
            currentLanguage = language
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - String Extension for Localization

extension String {
    /// Get localized string with current language
    var localized: String {
        let value = String(localized: String.LocalizationValue(self))
        #if DEBUG
        if LocalizationManager.debugMode && value == self {
            return "[\(self)]"
        }
        #endif
        return value
    }

    /// Get localized string with arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

// MARK: - LocalizationManager Debug Extension

extension LocalizationManager {
    /// Debug mode flag - shows missing keys with brackets
    #if DEBUG
    nonisolated(unsafe) static var debugMode: Bool = false
    #endif
}

// MARK: - APIClient Extension

extension APIClient {
    /// Update language preference on server
    func updateLanguagePreference(_ language: String) async throws {
        struct UpdateRequest: Encodable {
            let preferredLanguage: String
        }

        try await requestVoid(
            endpoint: "/users/me",
            method: .patch,
            body: UpdateRequest(preferredLanguage: language)
        )
    }
}
