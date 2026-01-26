import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let avatarUrl: String?
    let englishLevel: EnglishLevel
    let dailyGoalMinutes: Int
    let streakDays: Int
    let totalReadingMinutes: Int
    let totalWordsLearned: Int
    let booksCompleted: Int?
    let subscriptionTier: SubscriptionTier?
    let createdAt: Date

    var displayNameOrEmail: String {
        displayName ?? email ?? "Reader"
    }

    // Convenience properties for ProfileView
    var booksRead: Int { booksCompleted ?? 0 }
    var wordsLearned: Int { totalWordsLearned }
    var streak: Int { streakDays }
}

enum EnglishLevel: String, Codable, CaseIterable {
    case beginner = "BEGINNER"
    case elementary = "ELEMENTARY"
    case intermediate = "INTERMEDIATE"
    case upperIntermediate = "UPPER_INTERMEDIATE"
    case advanced = "ADVANCED"

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .elementary: return "Elementary"
        case .intermediate: return "Intermediate"
        case .upperIntermediate: return "Upper Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var description: String {
        switch self {
        case .beginner: return "New to English, learning basics"
        case .elementary: return "Can understand simple phrases"
        case .intermediate: return "Can handle everyday conversations"
        case .upperIntermediate: return "Comfortable with complex topics"
        case .advanced: return "Near-native fluency"
        }
    }

    var recommendedDifficulty: ClosedRange<Int> {
        switch self {
        case .beginner: return 1...3
        case .elementary: return 2...4
        case .intermediate: return 3...6
        case .upperIntermediate: return 5...8
        case .advanced: return 7...10
        }
    }
}

struct UserStats: Codable {
    let totalMinutes: Int
    let streakDays: Int
    let booksCompleted: Int
    let booksInProgress: Int
    let wordsLearned: Int
    let todayMinutes: Int
    let dailyGoalMinutes: Int
    let weeklyProgress: [DayProgress]
}

struct DayProgress: Codable, Identifiable {
    let date: String
    let minutes: Int

    var id: String { date }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: User
    let isNewUser: Bool
}
