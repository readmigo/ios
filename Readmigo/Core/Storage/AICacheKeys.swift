import Foundation

/// Utility for generating consistent cache keys for AI responses
enum AICacheKeys {
    private static let version = AICacheManager.cacheVersion

    // MARK: - Core AI Features (90 days TTL)

    /// Cache key for word explanation
    /// - Parameters:
    ///   - word: The word being explained
    ///   - sentence: The context sentence
    ///   - level: User's English level
    static func wordExplain(word: String, sentence: String, level: String) -> String {
        let sentenceHash = sentence.sha256Hash.prefix(16)
        return "ai:\(version):word:explain:\(word.lowercased()):\(sentenceHash):\(level.lowercased())"
    }

    /// Cache key for sentence simplification
    static func sentenceSimplify(sentence: String, level: String) -> String {
        let hash = sentence.sha256Hash.prefix(16)
        return "ai:\(version):sentence:simplify:\(hash):\(level.lowercased())"
    }

    /// Cache key for paragraph translation
    static func paragraphTranslate(paragraph: String, targetLanguage: String) -> String {
        let hash = paragraph.sha256Hash.prefix(16)
        return "ai:\(version):paragraph:translate:\(hash):\(targetLanguage.lowercased())"
    }

    // MARK: - Book Analysis (180 days TTL)

    /// Cache key for book summary
    static func bookSummary(bookId: String, length: String = "medium") -> String {
        return "ai:\(version):book:summary:\(bookId):\(length.lowercased())"
    }

    /// Cache key for chapter summary
    static func chapterSummary(bookId: String, chapterId: String) -> String {
        return "ai:\(version):chapter:summary:\(bookId):\(chapterId)"
    }

    /// Cache key for character analysis
    static func characterAnalysis(bookId: String, characterName: String? = nil) -> String {
        if let name = characterName {
            return "ai:\(version):book:character:\(bookId):\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
        }
        return "ai:\(version):book:characters:\(bookId)"
    }

    /// Cache key for plot analysis
    static func plotAnalysis(bookId: String, chapterRange: String? = nil) -> String {
        if let range = chapterRange {
            return "ai:\(version):book:plot:\(bookId):\(range)"
        }
        return "ai:\(version):book:plot:\(bookId)"
    }

    /// Cache key for theme analysis
    static func themeAnalysis(bookId: String) -> String {
        return "ai:\(version):book:theme:\(bookId)"
    }

    /// Cache key for difficulty analysis
    static func difficultyAnalysis(bookId: String) -> String {
        return "ai:\(version):book:difficulty:\(bookId)"
    }

    // MARK: - Author Info (365 days TTL)

    /// Cache key for author information
    static func authorInfo(authorName: String) -> String {
        let normalized = authorName.lowercased().replacingOccurrences(of: " ", with: "_")
        return "ai:\(version):author:info:\(normalized)"
    }

    /// Cache key for writing style analysis
    static func writingStyle(bookId: String) -> String {
        return "ai:\(version):book:style:\(bookId)"
    }

    // MARK: - Reading Assistance (90 days TTL)

    /// Cache key for grammar explanation
    static func grammarExplanation(sentence: String) -> String {
        let hash = sentence.sha256Hash.prefix(16)
        return "ai:\(version):grammar:explain:\(hash)"
    }

    /// Cache key for cultural background note
    static func culturalNote(text: String, bookId: String? = nil) -> String {
        let hash = text.sha256Hash.prefix(16)
        if let id = bookId {
            return "ai:\(version):cultural:note:\(id):\(hash)"
        }
        return "ai:\(version):cultural:note:\(hash)"
    }

    /// Cache key for reading guide
    static func readingGuide(bookId: String, level: String) -> String {
        return "ai:\(version):book:guide:\(bookId):\(level.lowercased())"
    }

    /// Cache key for similar books recommendation
    static func similarBooks(bookId: String, level: String? = nil) -> String {
        if let lvl = level {
            return "ai:\(version):book:similar:\(bookId):\(lvl.lowercased())"
        }
        return "ai:\(version):book:similar:\(bookId)"
    }

    // MARK: - Vocabulary (varies by type)

    /// Cache key for vocabulary context usage (90 days)
    static func vocabContext(word: String) -> String {
        return "ai:\(version):vocab:context:\(word.lowercased())"
    }

    /// Cache key for vocabulary associations (90 days)
    static func vocabAssociation(word: String, type: String = "all") -> String {
        return "ai:\(version):vocab:assoc:\(word.lowercased()):\(type.lowercased())"
    }

    /// Cache key for word family (365 days)
    static func vocabFamily(word: String) -> String {
        return "ai:\(version):vocab:family:\(word.lowercased())"
    }

    /// Cache key for mnemonic (90 days)
    static func vocabMnemonic(word: String, language: String = "zh") -> String {
        return "ai:\(version):vocab:mnemonic:\(word.lowercased()):\(language.lowercased())"
    }

    // MARK: - Comprehension (90 days)

    /// Cache key for comprehension check questions
    static func comprehensionCheck(passage: String, questionCount: Int) -> String {
        let hash = passage.sha256Hash.prefix(16)
        return "ai:\(version):comprehension:\(hash):\(questionCount)"
    }
}

// MARK: - TTL Constants

extension AICacheKeys {
    /// TTL values in days for different cache types
    enum TTL {
        /// Permanent-level content: author info, word families, writing style (365 days)
        static let permanent = 365

        /// Book-level content: summaries, analysis, character info (180 days)
        static let bookLevel = 180

        /// Content-level: word explanations, translations, grammar (90 days)
        static let contentLevel = 90
    }
}
