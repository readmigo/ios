import Foundation
import SwiftUI

// MARK: - Bookmark

struct Bookmark: Codable, Identifiable {
    let id: String
    let bookId: String
    let chapterId: String
    let userId: String
    let position: BookmarkPosition
    let type: BookmarkType
    var title: String?
    var note: String?
    var highlightColor: HighlightColor?
    let selectedText: String?
    let createdAt: Date
    var updatedAt: Date
    let syncedAt: Date?

    var isHighlight: Bool {
        type == .highlight
    }

    var isAnnotation: Bool {
        type == .annotation
    }
}

// MARK: - Bookmark Position

struct BookmarkPosition: Codable, Equatable {
    let chapterIndex: Int
    let paragraphIndex: Int?
    let characterOffset: Int?
    let scrollPercentage: Double
    let cfiPath: String? // EPUB CFI for precise location

    static func == (lhs: BookmarkPosition, rhs: BookmarkPosition) -> Bool {
        lhs.chapterIndex == rhs.chapterIndex &&
        lhs.paragraphIndex == rhs.paragraphIndex &&
        lhs.characterOffset == rhs.characterOffset
    }

    var description: String {
        if let paragraph = paragraphIndex {
            return "Chapter \(chapterIndex + 1), Paragraph \(paragraph + 1)"
        }
        return "Chapter \(chapterIndex + 1), \(Int(scrollPercentage * 100))%"
    }
}

// MARK: - Bookmark Type

enum BookmarkType: String, Codable, CaseIterable {
    case bookmark
    case highlight
    case annotation

    var displayName: String {
        switch self {
        case .bookmark: return "Bookmark"
        case .highlight: return "Highlight"
        case .annotation: return "Note"
        }
    }

    var icon: String {
        switch self {
        case .bookmark: return "bookmark.fill"
        case .highlight: return "highlighter"
        case .annotation: return "note.text"
        }
    }

    var color: Color {
        switch self {
        case .bookmark: return .blue
        case .highlight: return .yellow
        case .annotation: return .orange
        }
    }
}

// MARK: - Highlight Color

enum HighlightColor: String, Codable, CaseIterable {
    case yellow
    case green
    case blue
    case pink
    case purple
    case orange

    var color: Color {
        switch self {
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .pink: return .pink
        case .purple: return .purple
        case .orange: return .orange
        }
    }

    var backgroundColor: Color {
        color.opacity(0.3)
    }

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Navigation History

struct NavigationHistoryItem: Codable, Identifiable {
    let id: String
    let bookId: String
    let chapterId: String
    let position: BookmarkPosition
    let timestamp: Date
    let chapterTitle: String?
}

// MARK: - Reading Position

struct ReadingPosition: Codable {
    let bookId: String
    let chapterId: String
    let position: BookmarkPosition
    let lastReadAt: Date
    let deviceId: String

    static func current(bookId: String, chapterId: String, chapterIndex: Int, scrollPercentage: Double) -> ReadingPosition {
        ReadingPosition(
            bookId: bookId,
            chapterId: chapterId,
            position: BookmarkPosition(
                chapterIndex: chapterIndex,
                paragraphIndex: nil,
                characterOffset: nil,
                scrollPercentage: scrollPercentage,
                cfiPath: nil
            ),
            lastReadAt: Date(),
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        )
    }
}

// MARK: - Bookmark Request/Response

struct CreateBookmarkRequest: Codable {
    let bookId: String
    let chapterId: String
    let position: BookmarkPosition
    let type: BookmarkType
    let title: String?
    let note: String?
    let highlightColor: HighlightColor?
    let selectedText: String?
}

struct UpdateBookmarkRequest: Codable {
    let title: String?
    let note: String?
    let highlightColor: HighlightColor?
}

struct BookmarksResponse: Codable {
    let bookmarks: [Bookmark]
    let total: Int
}

// MARK: - Table of Contents

struct TableOfContentsItem: Codable, Identifiable {
    let id: String
    let title: String
    let level: Int
    let chapterId: String
    let position: BookmarkPosition?
    let children: [TableOfContentsItem]?

    var hasChildren: Bool {
        (children?.count ?? 0) > 0
    }
}

// MARK: - Reading Session

struct ReadingSessionRecord: Codable {
    let id: String
    let bookId: String
    let startPosition: BookmarkPosition
    let endPosition: BookmarkPosition
    let startTime: Date
    let endTime: Date
    let wordsRead: Int
    let pagesRead: Int

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationFormatted: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

// MARK: - Quick Navigation

struct QuickNavigationTarget: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let position: BookmarkPosition?
    let action: NavigationAction

    enum NavigationAction {
        case goToPosition(BookmarkPosition)
        case goToChapter(String)
        case goToBookmark(Bookmark)
        case goToPercentage(Double)
    }
}
