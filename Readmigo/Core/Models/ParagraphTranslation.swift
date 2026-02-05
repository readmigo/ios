import Foundation

// MARK: - Paragraph Translation Models

/// Available translations for a chapter
struct ChapterTranslationAvailability: Codable {
    let chapterId: String
    let availableLocales: [String]
    let paragraphCount: Int?
}

/// Single paragraph translation response
struct ParagraphTranslation: Codable, Identifiable {
    let chapterId: String
    let locale: String
    let paragraphIndex: Int
    let original: String
    let translation: String

    var id: String { "\(chapterId)_\(locale)_\(paragraphIndex)" }
}

/// Batch paragraph translations response
struct BatchParagraphTranslations: Codable {
    let chapterId: String
    let locale: String
    let paragraphs: [ParagraphTranslationItem]
}

/// Individual paragraph in batch response
struct ParagraphTranslationItem: Codable, Identifiable {
    let paragraphIndex: Int
    let original: String
    let translation: String

    var id: Int { paragraphIndex }
}

// MARK: - Translation Error

enum TranslationError: Error, LocalizedError {
    case notAvailable
    case unsupportedLocale
    case networkError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "translation.error.notAvailable".localized
        case .unsupportedLocale:
            return "translation.error.unsupportedLocale".localized
        case .networkError(let error):
            return error.localizedDescription
        case .unknown:
            return "translation.error.unknown".localized
        }
    }
}
