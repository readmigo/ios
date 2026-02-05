import Foundation

/// Service for fetching chapter paragraph translations
@MainActor
class TranslationService: ObservableObject {
    static let shared = TranslationService()

    // Supported translation locales (must match backend)
    static let supportedLocales = [
        "zh-Hans", "zh-Hant", "es", "hi", "ar", "pt", "ja", "ko", "fr", "de"
    ]

    // In-memory cache for translations
    private var cache: [String: ParagraphTranslation] = [:]
    private var availabilityCache: [String: ChapterTranslationAvailability] = [:]

    @Published var isLoading = false
    @Published var error: TranslationError?

    private init() {}

    // MARK: - Cache Keys

    private func cacheKey(bookId: String, chapterId: String, locale: String, paragraphIndex: Int) -> String {
        "\(bookId)_\(chapterId)_\(locale)_\(paragraphIndex)"
    }

    private func availabilityCacheKey(bookId: String, chapterId: String) -> String {
        "\(bookId)_\(chapterId)_availability"
    }

    // MARK: - Public API

    /// Get the translation locale based on app language settings
    var translationLocale: String {
        let language = LocalizationManager.shared.currentLanguage
        switch language {
        case .chineseSimplified:
            return "zh-Hans"
        case .chineseTraditional:
            return "zh-Hant"
        case .spanish:
            return "es"
        case .arabic:
            return "ar"
        case .portuguese:
            return "pt"
        case .indonesian:
            // Indonesian not in top 10, fallback to English (no translation needed)
            return "en"
        case .french:
            return "fr"
        case .japanese:
            return "ja"
        case .russian:
            // Russian not in top 10, fallback to English
            return "en"
        case .korean:
            return "ko"
        case .english:
            return "en"
        }
    }

    /// Check if translation is needed (non-English locale)
    var needsTranslation: Bool {
        translationLocale != "en"
    }

    /// Check if a locale is supported
    func isLocaleSupported(_ locale: String) -> Bool {
        Self.supportedLocales.contains(locale)
    }

    /// Get available translations for a chapter
    func getAvailableTranslations(bookId: String, chapterId: String) async -> ChapterTranslationAvailability? {
        let cacheKey = availabilityCacheKey(bookId: bookId, chapterId: chapterId)

        // Check cache first
        if let cached = availabilityCache[cacheKey] {
            return cached
        }

        do {
            let availability: ChapterTranslationAvailability = try await APIClient.shared.request(
                endpoint: APIEndpoints.chapterTranslationAvailable(bookId, chapterId)
            )
            availabilityCache[cacheKey] = availability
            return availability
        } catch {
            LoggingService.shared.warning(.network, "Failed to fetch translation availability: \(error.localizedDescription)", component: "TranslationService")
            return nil
        }
    }

    /// Get translation for a specific paragraph
    func getTranslation(
        bookId: String,
        chapterId: String,
        paragraphIndex: Int,
        locale: String? = nil
    ) async throws -> ParagraphTranslation {
        let targetLocale = locale ?? translationLocale

        // Check if locale is supported
        guard isLocaleSupported(targetLocale) else {
            throw TranslationError.unsupportedLocale
        }

        let key = cacheKey(bookId: bookId, chapterId: chapterId, locale: targetLocale, paragraphIndex: paragraphIndex)

        // Check cache first
        if let cached = cache[key] {
            return cached
        }

        isLoading = true
        error = nil

        do {
            let translation: ParagraphTranslation = try await APIClient.shared.request(
                endpoint: APIEndpoints.paragraphTranslation(bookId, chapterId, targetLocale, paragraphIndex)
            )

            // Cache the result
            cache[key] = translation
            isLoading = false

            return translation
        } catch let apiError as APIError {
            isLoading = false

            switch apiError {
            case .serverError(let statusCode, _) where statusCode == 404:
                let translationError = TranslationError.notAvailable
                error = translationError
                throw translationError
            case .serverError(let statusCode, _) where statusCode == 400:
                let translationError = TranslationError.unsupportedLocale
                error = translationError
                throw translationError
            default:
                let translationError = TranslationError.networkError(apiError)
                error = translationError
                throw translationError
            }
        } catch {
            isLoading = false
            let translationError = TranslationError.networkError(error)
            self.error = translationError
            throw translationError
        }
    }

    /// Clear cache for a specific chapter
    func clearCache(bookId: String, chapterId: String) {
        cache = cache.filter { !$0.key.hasPrefix("\(bookId)_\(chapterId)_") }
        availabilityCache.removeValue(forKey: availabilityCacheKey(bookId: bookId, chapterId: chapterId))
    }

    /// Clear all cache
    func clearAllCache() {
        cache.removeAll()
        availabilityCache.removeAll()
    }
}
