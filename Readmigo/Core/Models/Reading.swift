import Foundation

struct LibraryBook: Codable, Identifiable {
    let id: String
    let bookId: String
    let book: BookInfo
    let currentChapter: Int
    let currentPosition: String?
    let progressPercent: Double
    let status: ReadingStatus
    let totalReadingMinutes: Int
    let wordsLookedUp: Int
    let startedAt: Date?
    let finishedAt: Date?
    let lastReadAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var formattedProgress: String {
        "\(Int(progressPercent))%"
    }

    var formattedReadingTime: String {
        let hours = totalReadingMinutes / 60
        let minutes = totalReadingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct BookInfo: Codable {
    let id: String
    let title: String
    let author: String
    let coverUrl: String?
    let coverThumbUrl: String?
    let difficultyScore: Int?
    let wordCount: Int?
    let chapterCount: Int
}

enum ReadingStatus: String, Codable {
    case wantToRead = "WANT_TO_READ"
    case reading = "READING"
    case finished = "FINISHED"

    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        }
    }
}

struct ReadingSession: Codable {
    let bookId: String
    let chapterId: String
    let durationSeconds: Int
    let wordsRead: Int
    let wordsLookedUp: Int
}

struct UpdateProgressRequest: Codable {
    let currentChapter: Int?
    let currentPosition: String?
    let progressPercent: Double?
    let status: ReadingStatus?
}

struct AddToLibraryRequest: Codable {
    let bookId: String
    let status: String?
}

struct UpdateBookStatusRequest: Codable {
    let status: String
}

struct PaginatedLibrary: Codable {
    let items: [LibraryBook]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}
