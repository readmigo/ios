import Foundation

struct WordExplainRequest: Codable {
    let word: String
    let sentence: String
    let bookId: String?
    let chapterId: String?
}

struct SentenceSimplifyRequest: Codable {
    let sentence: String
    let bookId: String?
}

struct ParagraphTranslateRequest: Codable {
    let paragraph: String
    let targetLanguage: String?
    let preserveStyle: Bool?
    let bookId: String?
}

struct ContentQARequest: Codable {
    let question: String
    let context: String
    let bookTitle: String?
    let bookId: String?
}

struct AIResponse: Codable {
    let content: String
    let model: String?
    let provider: String?
    let usage: TokenUsage?
    let fromCache: Bool?

    /// Convenience initializer for creating cached responses
    static func cached(content: String) -> AIResponse {
        AIResponse(
            content: content,
            model: nil,
            provider: nil,
            usage: nil,
            fromCache: true
        )
    }

    /// Whether this response came from local or server cache
    var isCached: Bool {
        fromCache ?? false
    }
}

struct TokenUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

struct AIStreamChunk: Codable {
    let content: String
    let done: Bool
}

struct AIUsage: Codable {
    let today: Int
    let thisWeek: Int
    let thisMonth: Int
}

// Parsed word explanation
struct WordExplanation {
    let word: String
    let definition: String
    let translation: String
    let partOfSpeech: String
    let examples: [String]
    let relatedWords: [String]

    init(from response: String, word: String) {
        self.word = word
        // Parse AI response - this is a simplified parser
        // In production, you might want more sophisticated parsing
        let lines = response.components(separatedBy: "\n")

        var definition = ""
        var translation = ""
        var partOfSpeech = ""
        var examples: [String] = []
        var relatedWords: [String] = []

        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.lowercased().contains("definition") {
                currentSection = "definition"
            } else if trimmed.lowercased().contains("translation") || trimmed.lowercased().contains("翻译") {
                currentSection = "translation"
            } else if trimmed.lowercased().contains("part of speech") {
                currentSection = "pos"
            } else if trimmed.lowercased().contains("example") {
                currentSection = "examples"
            } else if trimmed.lowercased().contains("related") {
                currentSection = "related"
            } else {
                switch currentSection {
                case "definition":
                    definition += trimmed + " "
                case "translation":
                    translation += trimmed + " "
                case "pos":
                    partOfSpeech = trimmed
                case "examples":
                    if trimmed.hasPrefix("-") || trimmed.hasPrefix("•") {
                        examples.append(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
                    }
                case "related":
                    relatedWords.append(contentsOf: trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) })
                default:
                    break
                }
            }
        }

        self.definition = definition.trimmingCharacters(in: .whitespaces)
        self.translation = translation.trimmingCharacters(in: .whitespaces)
        self.partOfSpeech = partOfSpeech
        self.examples = examples
        self.relatedWords = relatedWords
    }
}
