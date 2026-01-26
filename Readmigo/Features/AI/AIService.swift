import Foundation

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isLoading = false
    @Published var error: String?
    @Published var lastResult: String?
    @Published var lastResultFromCache = false

    private init() {}

    /// Get the current user's English level for cache key generation
    private var userEnglishLevel: String {
        AuthManager.shared.currentUser?.englishLevel.rawValue ?? "INTERMEDIATE"
    }

    // MARK: - Convenience Methods for EnhancedReaderView

    func explain(text: String, context: String) async {
        isLoading = true
        lastResult = nil
        do {
            let response = try await explainWord(word: text, sentence: context, bookId: nil, chapterId: nil)
            lastResult = response.content
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func simplify(text: String) async {
        isLoading = true
        lastResult = nil
        do {
            let response = try await simplifySentence(sentence: text, bookId: nil)
            lastResult = response.content
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func translate(text: String) async {
        isLoading = true
        lastResult = nil
        do {
            let response = try await translateParagraph(paragraph: text, targetLanguage: "zh", bookId: nil)
            lastResult = response.content
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Word Explanation

    func explainWord(word: String, sentence: String, bookId: String?, chapterId: String?) async throws -> AIResponse {
        // Check local cache first
        let cacheKey = AICacheKeys.wordExplain(word: word, sentence: sentence, level: userEnglishLevel)

        if let cached = await AICacheManager.shared.get(key: cacheKey) {
            return AIResponse.cached(content: cached)
        }

        // Call API
        let request = WordExplainRequest(
            word: word,
            sentence: sentence,
            bookId: bookId,
            chapterId: chapterId
        )

        let response: AIResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.aiExplain,
            method: .post,
            body: request
        )

        // Cache the response (90 days for content-level)
        await AICacheManager.shared.set(
            key: cacheKey,
            content: response.content,
            ttlDays: AICacheKeys.TTL.contentLevel
        )

        return response
    }

    // MARK: - Sentence Simplification

    func simplifySentence(sentence: String, bookId: String?) async throws -> AIResponse {
        // Check local cache first
        let cacheKey = AICacheKeys.sentenceSimplify(sentence: sentence, level: userEnglishLevel)

        if let cached = await AICacheManager.shared.get(key: cacheKey) {
            return AIResponse.cached(content: cached)
        }

        // Call API
        let request = SentenceSimplifyRequest(
            sentence: sentence,
            bookId: bookId
        )

        let response: AIResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.aiSimplify,
            method: .post,
            body: request
        )

        // Cache the response (90 days)
        await AICacheManager.shared.set(
            key: cacheKey,
            content: response.content,
            ttlDays: AICacheKeys.TTL.contentLevel
        )

        return response
    }

    // MARK: - Translation

    func translateParagraph(paragraph: String, targetLanguage: String = "zh", bookId: String?) async throws -> AIResponse {
        // Check local cache first
        let cacheKey = AICacheKeys.paragraphTranslate(paragraph: paragraph, targetLanguage: targetLanguage)

        if let cached = await AICacheManager.shared.get(key: cacheKey) {
            return AIResponse.cached(content: cached)
        }

        // Call API
        let request = ParagraphTranslateRequest(
            paragraph: paragraph,
            targetLanguage: targetLanguage,
            preserveStyle: true,
            bookId: bookId
        )

        let response: AIResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.aiTranslate,
            method: .post,
            body: request
        )

        // Cache the response (90 days)
        await AICacheManager.shared.set(
            key: cacheKey,
            content: response.content,
            ttlDays: AICacheKeys.TTL.contentLevel
        )

        return response
    }

    // MARK: - Q&A

    func askQuestion(question: String, context: String, bookTitle: String?, bookId: String?) async throws -> AIResponse {
        let request = ContentQARequest(
            question: question,
            context: context,
            bookTitle: bookTitle,
            bookId: bookId
        )

        return try await APIClient.shared.request(
            endpoint: APIEndpoints.aiQA,
            method: .post,
            body: request
        )
    }

    // MARK: - Get Usage

    func getUsage() async throws -> AIUsage {
        return try await APIClient.shared.request(
            endpoint: APIEndpoints.aiUsage
        )
    }
}
