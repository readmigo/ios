import Foundation

// MARK: - FAQ Category

struct FAQCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String
    let description: String?
    let icon: String?
    let order: Int
    let faqCount: Int
    let faqs: [FAQ]

    /// Localized name based on current language
    var localizedName: String {
        Locale.current.language.languageCode?.identifier == "en" ? nameEn : name
    }
}

// MARK: - FAQ

struct FAQ: Codable, Identifiable, Hashable {
    let id: String
    let categoryId: String
    let question: String
    let questionEn: String
    let answer: String
    let answerEn: String
    let keywords: String?
    let order: Int
    let isPinned: Bool
    let viewCount: Int
    let helpfulYes: Int
    let helpfulNo: Int

    /// Localized question based on current language
    var localizedQuestion: String {
        Locale.current.language.languageCode?.identifier == "en" ? questionEn : question
    }

    /// Localized answer based on current language
    var localizedAnswer: String {
        Locale.current.language.languageCode?.identifier == "en" ? answerEn : answer
    }

    /// Helpfulness percentage
    var helpfulPercentage: Double {
        let total = helpfulYes + helpfulNo
        guard total > 0 else { return 0 }
        return Double(helpfulYes) / Double(total) * 100
    }
}

// MARK: - FAQ List Response

struct FAQListResponse: Codable {
    let categories: [FAQCategory]
}

// MARK: - FAQ Search Response

struct FAQSearchResponse: Codable {
    let results: [FAQ]
    let total: Int
}

// MARK: - FAQ Feedback Request

struct FAQFeedbackRequest: Codable {
    let faqId: String
    let helpful: Bool
}
