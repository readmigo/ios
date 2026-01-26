import Foundation

// MARK: - Overview Stats

struct OverviewStats: Codable {
    let totalReadingMinutes: Int
    let totalBooksRead: Int
    let totalWordsLearned: Int
    let currentStreak: Int
    let longestStreak: Int
    let todayMinutes: Int
    let weeklyMinutes: Int
    let monthlyMinutes: Int
    let aiInteractions: Int
}

// MARK: - Daily Stats

struct DailyStats: Codable, Identifiable {
    let date: String
    let readingMinutes: Int
    let pagesRead: Int
    let wordsLearned: Int
    let wordsReviewed: Int
    let reviewAccuracy: Double?
    let aiInteractions: Int
    let booksFinished: Int?

    var id: String { date }

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

// MARK: - Trend Direction

enum TrendDirection: String, Codable {
    case up = "UP"
    case down = "DOWN"
    case stable = "STABLE"

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var color: String {
        switch self {
        case .up: return "green"
        case .down: return "red"
        case .stable: return "gray"
        }
    }
}

// MARK: - Reading Trend

struct ReadingTrend: Codable {
    let period: String
    let data: [TrendDataPoint]
    let averageMinutes: Double
    let totalMinutes: Int
    let trend: TrendDirection
    let percentChange: Double?
}

struct TrendDataPoint: Codable, Identifiable {
    let date: String
    let value: Int

    var id: String { date }

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

// MARK: - Vocabulary Progress

struct VocabularyProgress: Codable {
    let totalWords: Int
    let masteredWords: Int
    let learningWords: Int
    let newWords: Int
    let retentionRate: Double
    let averageReviewsPerDay: Double
    let weeklyHistory: [DailyVocabStats]
}

struct DailyVocabStats: Codable, Identifiable {
    let date: String
    let wordsLearned: Int
    let wordsReviewed: Int
    let accuracy: Double

    var id: String { date }
}

// MARK: - Reading Progress

struct ReadingProgress: Codable {
    let currentlyReading: [BookProgress]
    let recentlyFinished: [BookProgress]
    let totalBooksStarted: Int
    let totalBooksFinished: Int
    let averageCompletionRate: Double
}

struct BookProgress: Codable, Identifiable {
    let bookId: String
    let title: String
    let author: String
    let coverUrl: String?
    let progressPercent: Double
    let lastReadAt: Date?
    let totalReadingMinutes: Int

    var id: String { bookId }
}

// MARK: - Response Models

struct OverviewStatsResponse: Codable {
    let stats: OverviewStats
}

struct DailyStatsResponse: Codable {
    let stats: [DailyStats]
    let period: String
}

struct ReadingTrendResponse: Codable {
    let trend: ReadingTrend
}

struct VocabularyProgressResponse: Codable {
    let progress: VocabularyProgress
}

struct ReadingProgressResponse: Codable {
    let progress: ReadingProgress
}
