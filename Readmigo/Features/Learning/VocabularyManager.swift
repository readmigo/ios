import Foundation

@MainActor
class VocabularyManager: ObservableObject {
    static let shared = VocabularyManager()

    @Published var words: [VocabularyWord] = []
    @Published var reviewWords: [VocabularyWord] = []
    @Published var stats: VocabularyStats?
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - Fetch Vocabulary

    func fetchVocabulary(page: Int = 1, limit: Int = 50) async {
        // Skip vocabulary fetch in guest mode
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.reading, "[VocabularyManager] Skipping fetchVocabulary in guest mode", component: "VocabularyManager")
            self.words = []
            return
        }

        isLoading = true
        error = nil

        do {
            let response: VocabularyListResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.vocabulary)?page=\(page)&limit=\(limit)"
            )

            if page == 1 {
                self.words = response.words
            } else {
                self.words.append(contentsOf: response.words)
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Review Words

    func fetchReviewWords() async {
        // Skip review words fetch in guest mode
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.reading, "[VocabularyManager] Skipping fetchReviewWords in guest mode", component: "VocabularyManager")
            self.reviewWords = []
            return
        }

        isLoading = true
        error = nil

        do {
            let response: VocabularyListResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.vocabularyReview
            )
            self.reviewWords = response.words
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Submit Review

    func submitReview(wordId: String, quality: Int) async throws {
        let request = ReviewRequest(quality: quality)
        let updatedWord: VocabularyWord = try await APIClient.shared.request(
            endpoint: APIEndpoints.vocabularyReviewItem(wordId),
            method: .post,
            body: request
        )

        // Update local state
        if let index = words.firstIndex(where: { $0.id == wordId }) {
            words[index] = updatedWord
        }

        // Remove from review list
        reviewWords.removeAll { $0.id == wordId }
    }

    // MARK: - Delete Word

    func deleteWord(id: String) async throws {
        let _: EmptyResponse = try await APIClient.shared.request(
            endpoint: "\(APIEndpoints.vocabulary)/\(id)",
            method: .delete
        )

        words.removeAll { $0.id == id }
        reviewWords.removeAll { $0.id == id }
    }

    // MARK: - Fetch Stats

    func fetchStats() async {
        // Skip stats fetch in guest mode
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.reading, "[VocabularyManager] Skipping fetchStats in guest mode", component: "VocabularyManager")
            stats = nil
            return
        }

        do {
            stats = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.vocabulary)/stats"
            )
        } catch {
            LoggingService.shared.debug(.reading, "Failed to fetch vocabulary stats: \(error)", component: "VocabularyManager")
        }
    }

    // MARK: - Search

    func search(query: String) async -> [VocabularyWord] {
        // Skip search in guest mode
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.reading, "[VocabularyManager] Skipping search in guest mode", component: "VocabularyManager")
            return []
        }

        guard !query.isEmpty else { return words }

        do {
            let response: VocabularyListResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.vocabulary)?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
            )
            return response.words
        } catch {
            return []
        }
    }
}

// MARK: - Response Models

struct VocabularyListResponse: Codable {
    let words: [VocabularyWord]
    let total: Int
}

struct ReviewRequest: Codable {
    let quality: Int
}

