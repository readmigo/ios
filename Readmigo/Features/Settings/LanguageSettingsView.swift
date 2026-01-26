import SwiftUI

/// Language selection settings view
struct LanguageSettingsView: View {
    @EnvironmentObject var localizationManager: LocalizationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            // System Language Option
            Section {
                Button {
                    localizationManager.resetToSystemLanguage()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("profile.useSystemLanguage".localized)
                                .foregroundColor(.primary)
                            Text(systemLanguageDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !localizationManager.hasManualSelection {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }

            // Manual Language Selection
            Section {
                ForEach(AppLanguage.allCases) { language in
                    Button {
                        selectLanguage(language)
                    } label: {
                        HStack {
                            Text(language.flag)

                            Text(language.displayName)
                                .foregroundColor(.primary)

                            Spacer()

                            if localizationManager.hasManualSelection &&
                                localizationManager.currentLanguage == language {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("Choose Language")
            }
        }
        .navigationTitle("profile.language".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var systemLanguageDescription: String {
        let systemLang = detectSystemLanguageName()
        return "Current: \(systemLang)"
    }

    private func detectSystemLanguageName() -> String {
        let preferredLanguages = Locale.preferredLanguages
        guard let first = preferredLanguages.first else {
            return "English"
        }

        if first.hasPrefix("zh-Hans") || first.hasPrefix("zh-CN") {
            return "Simplified Chinese"
        } else if first.hasPrefix("zh-Hant") || first.hasPrefix("zh-TW") || first.hasPrefix("zh-HK") {
            return "Traditional Chinese"
        } else if first.hasPrefix("zh") {
            return "Chinese"
        } else if first.hasPrefix("en") {
            return "English"
        }

        return Locale.current.localizedString(forLanguageCode: first) ?? first
    }

    private func selectLanguage(_ language: AppLanguage) {
        localizationManager.setLanguage(language)

        // Sync to server
        Task {
            await localizationManager.syncToServer()
        }
    }
}

// MARK: - Compact Language Picker (for use in Settings row)

struct LanguagePicker: View {
    @EnvironmentObject var localizationManager: LocalizationManager

    var body: some View {
        NavigationLink {
            LanguageSettingsView()
        } label: {
            HStack {
                Label("profile.language".localized, systemImage: "globe")

                Spacer()

                Text(currentLanguageLabel)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var currentLanguageLabel: String {
        if localizationManager.hasManualSelection {
            return localizationManager.currentLanguage.displayName
        } else {
            return "profile.useSystemLanguage".localized
        }
    }
}
