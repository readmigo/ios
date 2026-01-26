import Foundation

/// Changelog entry for version history
struct ChangelogEntry: Identifiable {
    let id = UUID()
    /// Version number
    let version: String
    /// Release date
    let date: Date
    /// Changes in this version (supports multiple languages)
    let changes: [LocalizedChange]

    /// Get localized changes based on current locale
    var localizedChanges: [String] {
        let languageCode = Locale.current.language.languageCode?.identifier ?? "en"
        return changes.map { $0.localized(for: languageCode) }
    }
}

/// Localized change description
struct LocalizedChange {
    let en: String
    let zhHans: String
    let zhHant: String

    func localized(for locale: String) -> String {
        switch locale {
        case "zh-Hans", "zh":
            return zhHans
        case "zh-Hant":
            return zhHant
        default:
            return en
        }
    }
}
