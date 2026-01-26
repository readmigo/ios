import Foundation

struct VocabularyWord: Codable, Identifiable {
    let id: String
    let word: String
    let context: String
    let definition: String?
    let translation: String?
    let note: String?
    let status: VocabStatus
    let easeFactor: Double
    let interval: Int
    let repetitions: Int
    let nextReviewAt: Date?
    let createdAt: Date
    let bookTitle: String?

    var isDueForReview: Bool {
        guard let nextReview = nextReviewAt else { return true }
        return nextReview <= Date()
    }

    // Compatibility alias
    var notes: String? { note }
}

enum VocabStatus: String, Codable {
    case new = "NEW"
    case learning = "LEARNING"
    case reviewing = "REVIEWING"
    case mastered = "MASTERED"

    var displayName: String {
        switch self {
        case .new: return "New"
        case .learning: return "Learning"
        case .reviewing: return "Reviewing"
        case .mastered: return "Mastered"
        }
    }

    var color: String {
        switch self {
        case .new: return "gray"
        case .learning: return "orange"
        case .reviewing: return "blue"
        case .mastered: return "green"
        }
    }
}

struct AddVocabularyRequest: Codable {
    let word: String
    let context: String
    let definition: String?
    let translation: String?
    let bookId: String?
    let chapterId: String?
}

struct ReviewResult: Codable {
    let vocabularyId: String
    let quality: Int // 0-5
}

struct BatchReviewRequest: Codable {
    let reviews: [ReviewResult]
}

struct ReviewSession: Codable {
    let words: [VocabularyWord]
    let totalDue: Int
    let newWords: Int
    let reviewWords: Int
}

struct VocabularyStats: Codable {
    let total: Int
    let new: Int
    let learning: Int
    let reviewing: Int
    let mastered: Int
    let dueToday: Int

    var masteryPercentage: Double {
        guard total > 0 else { return 0 }
        return Double(mastered) / Double(total) * 100
    }

    // Compatibility aliases for views
    var totalWords: Int { total }
    var newWords: Int { new }
    var learningWords: Int { learning }
    var masteredWords: Int { mastered }
    var streakDays: Int { 0 } // Not available in this model, default to 0
    var todayReviewed: Int { 0 } // Not available, default to 0
    var dueForReview: Int { dueToday }
}

struct PaginatedVocabulary: Codable {
    let items: [VocabularyWord]
    let total: Int
    let page: Int
    let limit: Int
    let totalPages: Int
}
