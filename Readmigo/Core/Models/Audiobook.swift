import Foundation
import SwiftUI

// MARK: - Listening Status

enum ListeningStatus: String, Codable {
    case notStarted = "NOT_STARTED"
    case inProgress = "IN_PROGRESS"
    case completed = "COMPLETED"

    var displayName: String {
        switch self {
        case .notStarted: return "Not Started"
        case .inProgress: return "Listening"
        case .completed: return "Completed"
        }
    }

    var icon: String {
        switch self {
        case .notStarted: return "play.circle"
        case .inProgress: return "headphones"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Audiobook Chapter

struct AudiobookChapter: Codable, Identifiable, Equatable {
    let id: String
    let chapterNumber: Int
    let title: String
    let duration: Int // in seconds
    let audioUrl: String
    let readerName: String?
    let bookChapterId: String? // For Whispersync with ebook

    var formattedDuration: String {
        let minutes = duration / 60
        let seconds = duration % 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func == (lhs: AudiobookChapter, rhs: AudiobookChapter) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audiobook

struct Audiobook: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let narrator: String?
    let description: String?
    let coverUrl: String?
    let totalDuration: Int // in seconds
    let bookId: String? // Associated ebook ID for Whispersync
    let source: String
    let language: String
    let genres: [String]
    let status: String
    let chapters: [AudiobookChapter]

    var formattedDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var chapterCount: Int {
        chapters.count
    }

    var hasBookSync: Bool {
        bookId != nil
    }

    var isActive: Bool {
        status == "ACTIVE"
    }

    static func == (lhs: Audiobook, rhs: Audiobook) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audiobook List Item (for lists without chapters)

struct AudiobookListItem: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let author: String
    let narrator: String?
    let coverUrl: String?
    let totalDuration: Int
    let bookId: String?
    let language: String
    let chapterCount: Int

    var formattedDuration: String {
        let hours = totalDuration / 3600
        let minutes = (totalDuration % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var hasBookSync: Bool {
        bookId != nil
    }

    static func == (lhs: AudiobookListItem, rhs: AudiobookListItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Audiobook Progress

struct AudiobookProgress: Codable {
    let audiobookId: String
    let currentChapter: Int
    let currentPosition: Int // in seconds
    let totalListened: Int // in seconds
    let playbackSpeed: Double
    let status: ListeningStatus
    let lastListenedAt: Date

    var formattedPosition: String {
        let minutes = currentPosition / 60
        let seconds = currentPosition % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedTotalListened: String {
        let hours = totalListened / 3600
        let minutes = (totalListened % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m listened"
        }
        return "\(minutes)m listened"
    }

    var playbackSpeedText: String {
        if playbackSpeed == 1.0 {
            return "1x"
        }
        return String(format: "%.1fx", playbackSpeed)
    }
}

// MARK: - Audiobook With Progress

struct AudiobookWithProgress: Codable, Identifiable {
    let id: String
    let title: String
    let author: String
    let narrator: String?
    let description: String?
    let coverUrl: String?
    let totalDuration: Int
    let bookId: String?
    let source: String
    let language: String
    let genres: [String]
    let status: String
    let chapters: [AudiobookChapter]
    let progress: AudiobookProgress?

    var audiobook: Audiobook {
        Audiobook(
            id: id,
            title: title,
            author: author,
            narrator: narrator,
            description: description,
            coverUrl: coverUrl,
            totalDuration: totalDuration,
            bookId: bookId,
            source: source,
            language: language,
            genres: genres,
            status: status,
            chapters: chapters
        )
    }

    var progressPercentage: Double {
        guard let progress = progress, totalDuration > 0 else { return 0 }
        return Double(progress.totalListened) / Double(totalDuration) * 100
    }

    var hasProgress: Bool {
        progress != nil && (progress?.status != .notStarted)
    }
}

// MARK: - Paginated Audiobooks Response

struct PaginatedAudiobooks: Codable {
    let items: [AudiobookListItem]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}

// MARK: - Audiobook Update Progress Request

struct AudiobookUpdateProgressRequest: Codable {
    let chapterIndex: Int
    let positionSeconds: Int
    let playbackSpeed: Double?
}

// MARK: - Start Listening Request

struct StartListeningRequest: Codable {
    let chapterIndex: Int?
    let positionSeconds: Int?
}

// MARK: - Playback Speed

enum PlaybackSpeed: Double, CaseIterable {
    case slow = 0.5
    case slower = 0.75
    case normal = 1.0
    case faster = 1.25
    case fast = 1.5
    case veryFast = 1.75
    case double = 2.0
    case faster2x = 2.5
    case triple = 3.0
    case max = 3.5

    var displayText: String {
        if self == .normal {
            return "1x"
        }
        return String(format: "%.1fx", rawValue).replacingOccurrences(of: ".0x", with: "x")
    }

    static var commonSpeeds: [PlaybackSpeed] {
        [.slower, .normal, .faster, .fast, .double]
    }
}

// MARK: - Sleep Timer Extension

extension SleepTimerOption {
    var displayText: String { displayName }

    var seconds: Int? {
        switch self {
        case .off: return nil
        case .endOfChapter: return nil
        default: return rawValue * 60
        }
    }
}

// MARK: - Source Badge View

struct AudiobookSourceBadge: View {
    let source: String

    private var displayName: String {
        switch source.uppercased() {
        case "LIBRIVOX": return "LibriVox"
        default: return source
        }
    }

    private var color: Color {
        switch source.uppercased() {
        case "LIBRIVOX": return .orange
        default: return .gray
        }
    }

    var body: some View {
        Text(displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .cornerRadius(8)
    }
}

// MARK: - Whispersync Badge View

struct WhispersyncBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.caption2)
            Text("Sync")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.15))
        .cornerRadius(8)
    }
}
