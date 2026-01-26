import Foundation

// MARK: - Timestamp Models

/// Word-level timestamp for precise highlighting
struct WordTimestamp: Codable, Identifiable {
    var id: String { "\(charStart)-\(charEnd)" }

    let word: String
    let startTime: Double
    let endTime: Double
    let charStart: Int
    let charEnd: Int
}

/// Segment-level timestamp (sentence/phrase)
struct TimestampSegment: Codable, Identifiable {
    var id: Int { segmentId }

    let segmentId: Int
    let startTime: Double
    let endTime: Double
    let text: String
    let charStart: Int
    let charEnd: Int
    let confidence: Double
    let words: [WordTimestamp]?

    enum CodingKeys: String, CodingKey {
        case segmentId = "id"
        case startTime
        case endTime
        case text
        case charStart
        case charEnd
        case confidence
        case words
    }
}

/// Chapter timestamps container
struct ChapterTimestamps: Codable {
    let version: Int
    let generatedAt: String
    let method: String  // "whisper", "gentle", "manual", "librivox"
    let language: String
    let duration: Double
    let segments: [TimestampSegment]
}

/// Bundled timestamps for offline use (all chapters)
struct AudiobookTimestamps: Codable {
    let audiobookId: String
    let bookId: String?
    let generatedAt: String
    let chapters: [String: ChapterTimestamps]  // chapterNumber string -> timestamps
}

// MARK: - Highlight Range

/// Represents a range in the text to highlight
struct HighlightRange: Equatable {
    let location: Int
    let length: Int

    var nsRange: NSRange {
        NSRange(location: location, length: length)
    }

    static let empty = HighlightRange(location: 0, length: 0)
}

// MARK: - API Response Models

/// Response from /audiobooks/:id/chapters/:chapterNumber/timestamps
struct ChapterTimestampsResponse: Codable {
    let audiobookId: String
    let chapterNumber: Int
    let timestamps: ChapterTimestamps?
    let hasTimestamps: Bool
}
