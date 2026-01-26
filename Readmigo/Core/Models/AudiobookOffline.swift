import Foundation

// MARK: - Downloaded Audiobook

/// Represents a fully or partially downloaded audiobook stored locally
struct DownloadedAudiobook: Codable, Identifiable {
    let id: String
    let audiobookId: String
    let title: String
    let author: String
    let narrator: String?
    let coverUrl: String?
    var coverLocalPath: String?
    let totalChapters: Int
    var downloadedChapters: Int
    let totalSizeBytes: Int64
    var downloadedSizeBytes: Int64
    var status: DownloadStatus
    let priority: DownloadPriority
    var downloadStartedAt: Date?
    var downloadCompletedAt: Date?
    var lastPlayedAt: Date?
    var chapters: [DownloadedAudiobookChapter]

    var progress: Double {
        guard totalChapters > 0 else { return 0 }
        return Double(downloadedChapters) / Double(totalChapters)
    }

    var isComplete: Bool {
        status == .completed && downloadedChapters == totalChapters
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: downloadedSizeBytes, countStyle: .file)
    }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    var formattedProgress: String {
        "\(Int(progress * 100))%"
    }

    /// Create from an Audiobook model
    static func from(_ audiobook: Audiobook) -> DownloadedAudiobook {
        DownloadedAudiobook(
            id: UUID().uuidString,
            audiobookId: audiobook.id,
            title: audiobook.title,
            author: audiobook.author,
            narrator: audiobook.narrator,
            coverUrl: audiobook.coverUrl,
            coverLocalPath: nil,
            totalChapters: audiobook.chapters.count,
            downloadedChapters: 0,
            totalSizeBytes: 0,
            downloadedSizeBytes: 0,
            status: .queued,
            priority: .normal,
            downloadStartedAt: nil,
            downloadCompletedAt: nil,
            lastPlayedAt: nil,
            chapters: audiobook.chapters.map { DownloadedAudiobookChapter.from($0) }
        )
    }
}

// MARK: - Downloaded Audiobook Chapter

/// Represents a downloaded chapter of an audiobook
struct DownloadedAudiobookChapter: Codable, Identifiable {
    let id: String
    let chapterId: String
    let audiobookId: String
    let title: String
    let chapterNumber: Int
    let duration: Int // seconds
    var localPath: String?
    var sizeBytes: Int64
    var status: DownloadStatus
    var downloadedAt: Date?
    let audioUrl: String

    var isDownloaded: Bool {
        status == .completed && localPath != nil
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    /// Create from an AudiobookChapter model
    static func from(_ chapter: AudiobookChapter, audiobookId: String = "") -> DownloadedAudiobookChapter {
        DownloadedAudiobookChapter(
            id: UUID().uuidString,
            chapterId: chapter.id,
            audiobookId: audiobookId,
            title: chapter.title,
            chapterNumber: chapter.chapterNumber,
            duration: chapter.duration,
            localPath: nil,
            sizeBytes: 0,
            status: .notDownloaded,
            downloadedAt: nil,
            audioUrl: chapter.audioUrl
        )
    }
}

// MARK: - Audiobook Download State

/// Tracks the current download state of an audiobook
struct AudiobookDownloadState: Codable {
    let audiobookId: String
    var overallProgress: Double
    var chapterProgress: [String: Double] // chapterId -> progress (0-1)
    var status: DownloadStatus
    var currentlyDownloadingChapterId: String?
    var error: String?
    var downloadSpeed: Double? // bytes per second
    var estimatedTimeRemaining: TimeInterval?

    var formattedSpeed: String? {
        guard let speed = downloadSpeed else { return nil }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return "\(formatter.string(fromByteCount: Int64(speed)))/s"
    }

    var formattedETA: String? {
        guard let eta = estimatedTimeRemaining, eta > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: eta)
    }
}

// MARK: - Download Info

/// Information about an active download task
struct AudiobookDownloadInfo: Codable {
    let taskId: String
    let audiobookId: String
    let chapterId: String
    let remoteUrl: String
    let destinationPath: String
    var resumeData: Data?
    var bytesDownloaded: Int64
    var totalBytes: Int64
    var status: DownloadStatus
    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var error: String?

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(bytesDownloaded) / Double(totalBytes)
    }
}

// MARK: - Audiobook Storage Info

/// Storage information specific to audiobooks
struct AudiobookStorageInfo: Codable {
    let totalDownloadedBytes: Int64
    let totalCachedBytes: Int64
    let downloadedAudiobookCount: Int
    let downloadedChapterCount: Int
    let availableSpace: Int64
    let maxStorageBytes: Int64

    var usedPercentage: Double {
        guard maxStorageBytes > 0 else { return 0 }
        return Double(totalDownloadedBytes) / Double(maxStorageBytes)
    }

    var formattedDownloadedSize: String {
        ByteCountFormatter.string(fromByteCount: totalDownloadedBytes, countStyle: .file)
    }

    var formattedCachedSize: String {
        ByteCountFormatter.string(fromByteCount: totalCachedBytes, countStyle: .file)
    }

    var formattedAvailableSpace: String {
        ByteCountFormatter.string(fromByteCount: availableSpace, countStyle: .file)
    }

    var formattedMaxStorage: String {
        ByteCountFormatter.string(fromByteCount: maxStorageBytes, countStyle: .file)
    }

    var hasStorageWarning: Bool {
        usedPercentage > 0.9 || availableSpace < 100_000_000 // 100MB
    }
}

