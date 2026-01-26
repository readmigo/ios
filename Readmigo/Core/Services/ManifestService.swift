import Foundation

// MARK: - Manifest Models

/// Version manifest from server
struct VersionManifest: Codable {
    let majorVersion: Int
    let minVersionRequired: String
    let latestVersion: String
    let releaseDate: String?
    let codename: String
    let content: ManifestContent
    let features: ManifestFeatures
    let platforms: ManifestPlatforms
    let storage: ManifestStorage
    let updatedAt: String?
}

struct ManifestContent: Codable {
    let ebooks: ContentInfo
    let authors: ContentInfo
    let audiobooks: ContentInfo

    struct ContentInfo: Codable {
        let count: Int
        let enabled: Bool
        let source: String?
    }
}

struct ManifestFeatures: Codable {
    let reading: ReadingFeatures
    let ai: AIFeatures
    let audiobooks: AudiobooksFeature
    let smartReading: SmartReadingFeature
    let contentImport: ContentImportFeature
    let community: CommunityFeature

    struct ReadingFeatures: Codable {
        let epub: Bool
        let highlights: Bool
        let bookmarks: Bool
        let notes: Bool
        let progressSync: Bool

        enum CodingKeys: String, CodingKey {
            case epub, highlights, bookmarks, notes
            case progressSync = "progress_sync"
        }
    }

    struct AIFeatures: Codable {
        let wordLookup: Bool
        let translation: Bool
        let grammar: Bool

        enum CodingKeys: String, CodingKey {
            case wordLookup = "word_lookup"
            case translation, grammar
        }
    }

    enum AudiobooksFeature: Codable {
        case disabled
        case enabled(AudiobooksConfig)

        struct AudiobooksConfig: Codable {
            let enabled: Bool
            let playback: Bool?
            let speedControl: Bool?
            let sleepTimer: Bool?
            let offlineDownload: Bool?
            let carplay: Bool?

            enum CodingKeys: String, CodingKey {
                case enabled, playback, carplay
                case speedControl = "speed_control"
                case sleepTimer = "sleep_timer"
                case offlineDownload = "offline_download"
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = boolValue ? .enabled(AudiobooksConfig(enabled: true, playback: nil, speedControl: nil, sleepTimer: nil, offlineDownload: nil, carplay: nil)) : .disabled
            } else {
                let config = try container.decode(AudiobooksConfig.self)
                self = config.enabled ? .enabled(config) : .disabled
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .disabled:
                try container.encode(false)
            case .enabled(let config):
                try container.encode(config)
            }
        }

        var isEnabled: Bool {
            switch self {
            case .disabled: return false
            case .enabled: return true
            }
        }
    }

    enum SmartReadingFeature: Codable {
        case disabled
        case enabled

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = boolValue ? .enabled : .disabled
            } else {
                self = .enabled
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .disabled: try container.encode(false)
            case .enabled: try container.encode(true)
            }
        }

        var isEnabled: Bool {
            switch self {
            case .disabled: return false
            case .enabled: return true
            }
        }
    }

    enum ContentImportFeature: Codable {
        case disabled
        case enabled

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = boolValue ? .enabled : .disabled
            } else {
                self = .enabled
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .disabled: try container.encode(false)
            case .enabled: try container.encode(true)
            }
        }

        var isEnabled: Bool {
            switch self {
            case .disabled: return false
            case .enabled: return true
            }
        }
    }

    enum CommunityFeature: Codable {
        case disabled
        case enabled

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let boolValue = try? container.decode(Bool.self) {
                self = boolValue ? .enabled : .disabled
            } else {
                self = .enabled
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .disabled: try container.encode(false)
            case .enabled: try container.encode(true)
            }
        }

        var isEnabled: Bool {
            switch self {
            case .disabled: return false
            case .enabled: return true
            }
        }
    }
}

struct ManifestPlatforms: Codable {
    let ios: PlatformInfo
    let android: PlatformInfo
    let web: PlatformInfo

    struct PlatformInfo: Codable {
        let minVersion: String?
        let currentVersion: String?
        let enabled: Bool
        let storeUrl: String?
    }
}

struct ManifestStorage: Codable {
    let paths: StoragePaths
    let estimatedSize: String

    struct StoragePaths: Codable {
        let epubs: String
        let covers: String
        let authors: String
        let audiobooks: String?
        let audiobookCovers: String?
        let enhancements: String?
        let userContent: String?
        let community: String?
    }
}

// MARK: - Manifest Service

/// Service to fetch and cache version manifest
@MainActor
class ManifestService: ObservableObject {
    static let shared = ManifestService()

    @Published private(set) var manifest: VersionManifest?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let cacheKey = "cached_manifest"
    private let cacheExpiryKey = "cached_manifest_expiry"
    private let cacheDuration: TimeInterval = 5 * 60 // 5 minutes

    private init() {
        loadCachedManifest()
    }

    // MARK: - Public API

    /// Fetch manifest from server
    func fetchManifest() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let manifest: VersionManifest = try await APIClient.shared.request(
                endpoint: APIEndpoints.versionManifest
            )
            self.manifest = manifest
            cacheManifest(manifest)
            LoggingService.shared.info(.app, "Manifest fetched: V\(manifest.majorVersion) (\(manifest.codename))", component: "ManifestService")
        } catch {
            self.error = error
            LoggingService.shared.error(.app, "Failed to fetch manifest: \(error.localizedDescription)", component: "ManifestService")
        }

        isLoading = false
    }

    /// Check if a feature is available
    func isFeatureAvailable(_ feature: Feature) -> Bool {
        guard let manifest = manifest else {
            // If no manifest, assume V1 features only
            return feature.isV1Feature
        }

        switch feature {
        case .audiobooks:
            return manifest.features.audiobooks.isEnabled
        case .smartReading:
            return manifest.features.smartReading.isEnabled
        case .contentImport:
            return manifest.features.contentImport.isEnabled
        case .community:
            return manifest.features.community.isEnabled
        case .reading, .ai:
            return true // Always available
        }
    }

    /// Get content limits
    var contentLimits: ContentLimits {
        guard let manifest = manifest else {
            // Default V1 limits
            return ContentLimits(ebooks: 300, authors: 100, audiobooks: 0)
        }

        return ContentLimits(
            ebooks: manifest.content.ebooks.enabled ? manifest.content.ebooks.count : 0,
            authors: manifest.content.authors.enabled ? manifest.content.authors.count : 0,
            audiobooks: manifest.content.audiobooks.enabled ? manifest.content.audiobooks.count : 0
        )
    }

    /// Current major version from manifest
    var majorVersion: Int {
        manifest?.majorVersion ?? 1
    }

    // MARK: - Feature Enum

    enum Feature {
        case reading
        case ai
        case audiobooks
        case smartReading
        case contentImport
        case community

        var isV1Feature: Bool {
            switch self {
            case .reading, .ai: return true
            case .audiobooks, .smartReading, .contentImport, .community: return false
            }
        }
    }

    struct ContentLimits {
        let ebooks: Int
        let authors: Int
        let audiobooks: Int
    }

    // MARK: - Caching

    private func loadCachedManifest() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let expiry = UserDefaults.standard.object(forKey: cacheExpiryKey) as? Date,
              expiry > Date() else {
            return
        }

        do {
            let decoder = JSONDecoder()
            manifest = try decoder.decode(VersionManifest.self, from: data)
            LoggingService.shared.debug(.app, "Loaded cached manifest", component: "ManifestService")
        } catch {
            LoggingService.shared.warning(.app, "Failed to decode cached manifest: \(error.localizedDescription)", component: "ManifestService")
        }
    }

    private func cacheManifest(_ manifest: VersionManifest) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(manifest)
            UserDefaults.standard.set(data, forKey: cacheKey)
            UserDefaults.standard.set(Date().addingTimeInterval(cacheDuration), forKey: cacheExpiryKey)
        } catch {
            LoggingService.shared.warning(.app, "Failed to cache manifest: \(error.localizedDescription)", component: "ManifestService")
        }
    }
}
