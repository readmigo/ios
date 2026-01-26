import Foundation

// MARK: - Download Status

enum DownloadStatus: String, Codable {
    case notDownloaded = "NOT_DOWNLOADED"
    case queued = "QUEUED"
    case downloading = "DOWNLOADING"
    case paused = "PAUSED"
    case completed = "COMPLETED"
    case failed = "FAILED"

    var displayName: String {
        switch self {
        case .notDownloaded: return "Not Downloaded"
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .paused: return "Paused"
        case .completed: return "Downloaded"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .notDownloaded: return "arrow.down.circle"
        case .queued: return "clock"
        case .downloading: return "arrow.down.circle.fill"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle"
        }
    }
}

// MARK: - Download Priority

enum DownloadPriority: Int, Codable, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3

    static func < (lhs: DownloadPriority, rhs: DownloadPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Downloaded Book

struct DownloadedBook: Codable, Identifiable {
    let id: String
    let bookId: String
    let title: String
    var titleZh: String? = nil
    let author: String
    var authorZh: String? = nil
    let coverUrl: String?
    let coverLocalPath: String?
    let totalChapters: Int
    let downloadedChapters: Int
    let totalSizeBytes: Int64
    let downloadedSizeBytes: Int64
    let status: DownloadStatus
    let priority: DownloadPriority
    let downloadStartedAt: Date?
    let downloadCompletedAt: Date?
    let lastAccessedAt: Date?
    let expiresAt: Date?
    let errorMessage: String?

    var progress: Double {
        guard totalChapters > 0 else { return 0 }
        return Double(downloadedChapters) / Double(totalChapters)
    }

    var isComplete: Bool {
        status == .completed && downloadedChapters == totalChapters
    }

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: downloadedSizeBytes, countStyle: .file)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    // MARK: - Localized Accessors

    var localizedTitle: String {
        switch LocaleHelper.currentLanguage {
        case .chinese:
            if let zhTitle = titleZh, !zhTitle.isEmpty {
                return zhTitle
            }
            return title
        case .japanese, .korean, .english:
            return title
        }
    }

    var localizedAuthor: String {
        switch LocaleHelper.currentLanguage {
        case .chinese:
            if let zhAuthor = authorZh, !zhAuthor.isEmpty {
                return zhAuthor
            }
            return author
        case .japanese, .korean, .english:
            return author
        }
    }
}

// MARK: - Downloaded Chapter

struct DownloadedChapter: Codable, Identifiable {
    let id: String
    let bookId: String
    let chapterId: String
    let title: String
    let orderIndex: Int
    let localPath: String
    let sizeBytes: Int64
    let downloadedAt: Date
    let contentHash: String

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

// MARK: - Download Task

struct DownloadTask: Codable, Identifiable {
    let id: String
    let bookId: String
    let chapterId: String?
    let type: DownloadTaskType
    var status: DownloadStatus
    var priority: DownloadPriority
    var progress: Double
    var bytesDownloaded: Int64
    var totalBytes: Int64
    var retryCount: Int
    let maxRetries: Int
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var errorMessage: String?

    enum DownloadTaskType: String, Codable {
        case book
        case chapter
        case cover
        case metadata
    }

    var canRetry: Bool {
        status == .failed && retryCount < maxRetries
    }

    var formattedProgress: String {
        "\(Int(progress * 100))%"
    }
}

// MARK: - Offline Content

struct OfflineContent: Codable {
    let bookId: String
    let chapterId: String
    let content: String
    let metadata: OfflineMetadata
    let cachedAt: Date
    let expiresAt: Date?
}

struct OfflineMetadata: Codable {
    let title: String
    let author: String
    let chapterTitle: String
    let orderIndex: Int
    let wordCount: Int
    let previousChapterId: String?
    let nextChapterId: String?
}

// MARK: - Storage Info

struct StorageInfo: Codable {
    let totalSpace: Int64
    let usedSpace: Int64
    let availableSpace: Int64
    let offlineContentSize: Int64
    let cacheSize: Int64

    var usedPercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(usedSpace) / Double(totalSpace)
    }

    var offlinePercentage: Double {
        guard totalSpace > 0 else { return 0 }
        return Double(offlineContentSize) / Double(totalSpace)
    }

    var formattedTotalSpace: String {
        ByteCountFormatter.string(fromByteCount: totalSpace, countStyle: .file)
    }

    var formattedUsedSpace: String {
        ByteCountFormatter.string(fromByteCount: usedSpace, countStyle: .file)
    }

    var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }

    var formattedOfflineSize: String {
        ByteCountFormatter.string(fromByteCount: offlineContentSize, countStyle: .file)
    }
}

// MARK: - Offline Settings

struct OfflineSettings: Codable, Equatable {
    var autoDownloadEnabled: Bool
    var downloadOnWifiOnly: Bool
    var maxStorageBytes: Int64
    var autoDeleteAfterDays: Int?
    var predownloadNextChapters: Int
    var downloadQuality: DownloadQuality

    // Audiobook-specific settings
    var maxAudiobookStorageBytes: Int64
    var audioPredownloadNextChapters: Int
    var audiobookDownloadOnWifiOnly: Bool

    enum DownloadQuality: String, Codable {
        case low
        case medium
        case high

        var displayName: String {
            switch self {
            case .low: return "Low (Smaller files)"
            case .medium: return "Medium"
            case .high: return "High (Better quality)"
            }
        }
    }

    static var `default`: OfflineSettings {
        OfflineSettings(
            autoDownloadEnabled: true,
            downloadOnWifiOnly: true,
            maxStorageBytes: 1_000_000_000, // 1GB
            autoDeleteAfterDays: 30,
            predownloadNextChapters: 3,
            downloadQuality: .medium,
            maxAudiobookStorageBytes: 2_000_000_000, // 2GB
            audioPredownloadNextChapters: 2,
            audiobookDownloadOnWifiOnly: true
        )
    }

    // Default storage limit for audiobooks (used by AudioCacheManager)
    static let defaultMaxAudiobookStorageBytes: Int64 = 2_000_000_000 // 2GB
}

// MARK: - Sync Status

struct SyncStatus: Codable {
    let lastSyncAt: Date?
    let pendingUploads: Int
    let pendingDownloads: Int
    let isSyncing: Bool
    let lastError: String?

    var hasPendingSync: Bool {
        pendingUploads > 0 || pendingDownloads > 0
    }

    var statusText: String {
        if isSyncing {
            return "Syncing..."
        } else if let error = lastError {
            return "Sync failed: \(error)"
        } else if hasPendingSync {
            return "\(pendingUploads + pendingDownloads) items pending"
        } else if let lastSync = lastSyncAt {
            let formatter = RelativeDateTimeFormatter()
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced"
        }
    }
}

// MARK: - Network Status

enum NetworkStatus {
    case unknown
    case notConnected
    case wifi
    case cellular

    var canDownload: Bool {
        switch self {
        case .wifi: return true
        case .cellular: return true // Will check settings
        case .notConnected, .unknown: return false
        }
    }

    var displayName: String {
        switch self {
        case .unknown: return "Unknown"
        case .notConnected: return "No Connection"
        case .wifi: return "Wi-Fi"
        case .cellular: return "Cellular"
        }
    }

    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .notConnected: return "wifi.slash"
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        }
    }
}
