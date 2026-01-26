import Foundation

// MARK: - Report Status

enum ReportStatus: String, Codable {
    case pending = "PENDING"
    case generating = "GENERATING"
    case completed = "COMPLETED"
    case failed = "FAILED"
}

// MARK: - Reading Time Preference

enum ReadingTimePreference: String, Codable {
    case earlyBird = "EARLY_BIRD"
    case nightOwl = "NIGHT_OWL"
    case flexible = "FLEXIBLE"
    case balanced = "BALANCED"

    var localizedName: String {
        switch self {
        case .earlyBird: return String(localized: "annual_report.preference.early_bird")
        case .nightOwl: return String(localized: "annual_report.preference.night_owl")
        case .flexible: return String(localized: "annual_report.preference.flexible")
        case .balanced: return String(localized: "annual_report.preference.balanced")
        }
    }

    var icon: String {
        switch self {
        case .earlyBird: return "sunrise"
        case .nightOwl: return "moon.stars"
        case .flexible: return "clock"
        case .balanced: return "scale.3d"
        }
    }
}

// MARK: - Preferred Reading Days

enum PreferredReadingDays: String, Codable {
    case weekend = "WEEKEND"
    case weekday = "WEEKDAY"
    case balanced = "BALANCED"

    var localizedName: String {
        switch self {
        case .weekend: return String(localized: "annual_report.preference.weekend")
        case .weekday: return String(localized: "annual_report.preference.weekday")
        case .balanced: return String(localized: "annual_report.preference.balanced")
        }
    }
}

// MARK: - Book Detail

struct AnnualReportBookDetail: Codable, Identifiable {
    let id: String
    let bookId: String
    let title: String
    let author: String
    let coverUrl: String?
    let progressPercent: Double
    let status: String
    let finishedAt: Date?
    let readingMinutes: Int

    var isFinished: Bool {
        status == "FINISHED"
    }
}

// MARK: - Reading Overview

struct ReadingOverview: Codable {
    let totalBooks: Int
    let finishedBooks: Int
    let totalReadingMinutes: Int
    let totalPages: Int
    let completionRate: Int
    let booksDetail: [AnnualReportBookDetail]

    var totalReadingHours: Int {
        totalReadingMinutes / 60
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

// MARK: - Highlight Moment

struct HighlightMoment: Codable {
    let date: String
    let value: Int
    let context: String?

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    var formattedDate: String {
        guard let date = dateValue else { return self.date }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct FirstSubscription: Codable {
    let date: String
    let planType: String

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }
}

// MARK: - Highlights

struct Highlights: Codable {
    let longestReadingDay: HighlightMoment?
    let latestReadingNight: HighlightMoment?
    let mostNotesDay: HighlightMoment?
    let mostCommentsDay: HighlightMoment?
    let mostAgoraPostsDay: HighlightMoment?
    let mostFeedbackDay: HighlightMoment?
    let firstSubscriptionDay: FirstSubscription?

    var hasAnyHighlight: Bool {
        longestReadingDay != nil ||
        latestReadingNight != nil ||
        mostNotesDay != nil ||
        mostCommentsDay != nil ||
        mostAgoraPostsDay != nil ||
        firstSubscriptionDay != nil
    }
}

// MARK: - Social Ranking

struct SocialRanking: Codable {
    let readingTimePercentile: Int
    let booksReadPercentile: Int
    let vocabularyPercentile: Int

    var topPercentile: Int {
        max(readingTimePercentile, booksReadPercentile, vocabularyPercentile)
    }
}

// MARK: - Genre Preference

struct GenrePreference: Codable, Identifiable {
    let genre: String
    let count: Int
    let percentage: Int

    var id: String { genre }
}

// MARK: - AI Usage Preference

struct AIUsagePreference: Codable, Identifiable {
    let type: String
    let count: Int
    let percentage: Int

    var id: String { type }

    var localizedType: String {
        switch type {
        case "EXPLAIN": return String(localized: "ai.type.explain")
        case "TRANSLATE": return String(localized: "ai.type.translate")
        case "SIMPLIFY": return String(localized: "ai.type.simplify")
        case "QA": return String(localized: "ai.type.qa")
        case "AUTHOR_CHAT": return String(localized: "ai.type.author_chat")
        default: return type
        }
    }
}

// MARK: - Preferences

struct Preferences: Codable {
    let readingTimePreference: String
    let preferredReadingDays: String
    let avgSessionMinutes: Int
    let favoriteGenres: [GenrePreference]
    let aiUsagePreference: [AIUsagePreference]

    var readingTimePreferenceEnum: ReadingTimePreference {
        ReadingTimePreference(rawValue: readingTimePreference) ?? .flexible
    }

    var preferredReadingDaysEnum: PreferredReadingDays {
        PreferredReadingDays(rawValue: preferredReadingDays) ?? .balanced
    }
}

// MARK: - Personalization

struct Personalization: Codable {
    let badges: [String]
    let title: String
    let summary: String
    let summaryLocalized: [String: String]?

    func localizedSummary(for languageCode: String) -> String {
        summaryLocalized?[languageCode] ?? summary
    }
}

// MARK: - Annual Report

struct AnnualReport: Codable, Identifiable {
    let id: String
    let year: Int
    let status: String
    let generatedAt: Date?
    let readingOverview: ReadingOverview
    let highlights: Highlights
    let socialRanking: SocialRanking
    let preferences: Preferences
    let personalization: Personalization
    let shareCardUrl: String?

    var statusEnum: ReportStatus {
        ReportStatus(rawValue: status) ?? .pending
    }

    var isCompleted: Bool {
        statusEnum == .completed
    }

    var isGenerating: Bool {
        statusEnum == .generating
    }
}

// MARK: - Report Status Response

struct AnnualReportStatusResponse: Codable {
    let status: String
    let generatedAt: Date?
    let progress: Int?

    var statusEnum: ReportStatus {
        ReportStatus(rawValue: status) ?? .pending
    }
}

// MARK: - Report History Response

struct AnnualReportHistoryResponse: Codable {
    let years: [Int]
    let currentYear: Int
}

// MARK: - Share Page Response

struct SharePageResponse: Codable {
    let url: String
    let shareId: String
}

// MARK: - Share Log Request

struct ShareLogRequest: Codable {
    let platform: String
}
