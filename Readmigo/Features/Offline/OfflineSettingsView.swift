import SwiftUI

struct OfflineSettingsView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var localSettings: OfflineSettings = .default
    @State private var showClearCacheAlert = false

    var body: some View {
        Form {
            // Auto Download
            Section {
                Toggle("offline.autoDownload".localized, isOn: $localSettings.autoDownloadEnabled)

                if localSettings.autoDownloadEnabled {
                    Toggle("offline.wifiOnly".localized, isOn: $localSettings.downloadOnWifiOnly)

                    Stepper(value: $localSettings.predownloadNextChapters, in: 1...10) {
                        HStack {
                            Text("offline.predownloadChapters".localized)
                            Spacer()
                            Text("\(localSettings.predownloadNextChapters)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("offline.automaticDownloads".localized)
            } footer: {
                Text("offline.automaticDownloadsHint".localized)
            }

            // Download Quality
            Section("offline.downloadQuality".localized) {
                Picker("offline.quality".localized, selection: $localSettings.downloadQuality) {
                    ForEach([OfflineSettings.DownloadQuality.low, .medium, .high], id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.menu)
            }

            // Storage Management
            Section {
                HStack {
                    Text("offline.maxStorage".localized)
                    Spacer()
                    Picker("", selection: $localSettings.maxStorageBytes) {
                        Text("offline.storage.500mb".localized).tag(Int64(500_000_000))
                        Text("offline.storage.1gb".localized).tag(Int64(1_000_000_000))
                        Text("offline.storage.2gb".localized).tag(Int64(2_000_000_000))
                        Text("offline.storage.5gb".localized).tag(Int64(5_000_000_000))
                        Text("offline.storage.unlimited".localized).tag(Int64(0))
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("offline.autoDeleteAfter".localized)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { localSettings.autoDeleteAfterDays ?? 0 },
                        set: { localSettings.autoDeleteAfterDays = $0 == 0 ? nil : $0 }
                    )) {
                        Text("offline.delete.never".localized).tag(0)
                        Text("offline.delete.7days".localized).tag(7)
                        Text("offline.delete.14days".localized).tag(14)
                        Text("offline.delete.30days".localized).tag(30)
                        Text("offline.delete.60days".localized).tag(60)
                        Text("offline.delete.90days".localized).tag(90)
                    }
                    .pickerStyle(.menu)
                }
            } header: {
                Text("offline.storageSection".localized)
            } footer: {
                Text("offline.autoDeleteHint".localized)
            }

            // Current Usage
            if let storageInfo = offlineManager.storageInfo {
                Section("offline.currentUsage".localized) {
                    HStack {
                        Text("offline.offlineContent".localized)
                        Spacer()
                        Text(storageInfo.formattedOfflineSize)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("offline.cache".localized)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: storageInfo.cacheSize, countStyle: .file))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("offline.availableSpace".localized)
                        Spacer()
                        Text(storageInfo.formattedAvailableSpace)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Clear Cache
            Section {
                Button(role: .destructive) {
                    showClearCacheAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("offline.clearCache".localized)
                    }
                }
            }
        }
        .navigationTitle("offline.settingsTitle".localized)
        .onAppear {
            localSettings = offlineManager.settings
        }
        .onChange(of: localSettings) { _, newValue in
            offlineManager.updateSettings(newValue)
        }
        .alert("offline.clearCacheTitle".localized, isPresented: $showClearCacheAlert) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.clear".localized, role: .destructive) {
                Task {
                    try? await ContentCache.shared.clearCache()
                    await offlineManager.refreshStorageInfo()
                }
            }
        } message: {
            Text("offline.clearCacheMessage".localized)
        }
    }
}
