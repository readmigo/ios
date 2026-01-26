import SwiftUI
import Kingfisher

/// Developer tools view for debug and staging environments
struct DeveloperToolsView: View {
    @ObservedObject private var environmentManager = EnvironmentManager.shared

    var body: some View {
        #if DEBUG
        List {
            // Environment Section
            Section {
                EnvironmentSwitcher()
            } header: {
                Text("API Environment")
            } footer: {
                Text("Current API: \(environmentManager.apiBaseURL)")
                    .font(.caption2)
            }

            // Debug Info Section
            Section("App Info") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                }
                LabeledContent("Build") {
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                }
                LabeledContent("Environment") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(environmentManager.current.color)
                            .frame(width: 8, height: 8)
                        Text(environmentManager.current.displayName)
                    }
                }
            }

            // Cache Section
            Section("Cache") {
                Button("Clear Image Cache") {
                    clearImageCache()
                }
                .foregroundColor(.blue)

                Button("Clear All Caches") {
                    clearAllCaches()
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Developer Tools".localized)
        .navigationBarTitleDisplayMode(.inline)
        #else
        Text("Developer tools are only available in debug builds.")
            .foregroundColor(.secondary)
        #endif
    }

    private func clearImageCache() {
        // Clear Kingfisher image cache
        let cache = KingfisherManager.shared.cache
        cache.clearMemoryCache()
        cache.clearDiskCache()
    }

    private func clearAllCaches() {
        clearImageCache()
        URLCache.shared.removeAllCachedResponses()
    }
}
