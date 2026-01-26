import Foundation

@MainActor
class FAQService: ObservableObject {
    static let shared = FAQService()

    // MARK: - Published Properties

    @Published var categories: [FAQCategory] = []
    @Published var featuredFAQs: [FAQ] = []
    @Published var searchResults: [FAQ] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private var currentLanguage: String {
        Locale.current.language.languageCode?.identifier ?? "zh"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - API Methods

    /// Load all FAQ categories with FAQs
    func loadAllFAQs() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: FAQListResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.faq)?lang=\(currentLanguage)",
                method: .get
            )
            categories = response.categories
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Load featured/pinned FAQs
    func loadFeaturedFAQs() async {
        do {
            featuredFAQs = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.faqFeatured)?lang=\(currentLanguage)",
                method: .get
            )
        } catch {
            // Featured FAQs are optional, don't show error
        }
    }

    /// Load popular FAQs
    func loadPopularFAQs(limit: Int = 10) async -> [FAQ] {
        do {
            let faqs: [FAQ] = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.faqPopular)?lang=\(currentLanguage)&limit=\(limit)",
                method: .get
            )
            return faqs
        } catch {
            return []
        }
    }

    /// Search FAQs
    func searchFAQs(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            let response: FAQSearchResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.faqSearch)?q=\(encodedQuery)&lang=\(currentLanguage)",
                method: .get
            )
            searchResults = response.results
        } catch {
            self.error = error.localizedDescription
            searchResults = []
        }
    }

    /// Get FAQs by category
    func getFAQsByCategory(_ categoryId: String) async -> [FAQ] {
        do {
            let faqs: [FAQ] = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.faqCategory(categoryId))?lang=\(currentLanguage)",
                method: .get
            )
            return faqs
        } catch {
            return []
        }
    }

    /// Get FAQ detail (also increments view count)
    func getFAQDetail(_ id: String) async -> FAQ? {
        do {
            let faq: FAQ = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.faqDetail(id))?lang=\(currentLanguage)",
                method: .get
            )
            return faq
        } catch {
            return nil
        }
    }

    /// Submit feedback for a FAQ
    func submitFeedback(faqId: String, helpful: Bool) async -> Bool {
        do {
            let request = FAQFeedbackRequest(faqId: faqId, helpful: helpful)
            try await APIClient.shared.requestVoid(
                endpoint: APIEndpoints.faqFeedback,
                method: .post,
                body: request
            )
            return true
        } catch {
            return false
        }
    }

    /// Clear search results
    func clearSearch() {
        searchResults = []
    }
}
