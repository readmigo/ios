import Foundation
import SwiftUI

@MainActor
class PostcardsManager: ObservableObject {
    static let shared = PostcardsManager()

    // MARK: - Published Properties

    @Published var postcards: [Postcard] = []
    @Published var templates: [PostcardTemplate] = []
    @Published var selectedPostcard: Postcard?
    @Published var isLoading = false
    @Published var isLoadingTemplates = false
    @Published var error: String?

    // MARK: - Pagination

    @Published var currentPage = 1
    @Published var totalCount = 0
    @Published var hasMorePages = true

    private let pageSize = 20
    private let templatesCacheKey = "cached_postcard_templates"
    private let templatesCacheTimeKey = "cached_postcard_templates_time"
    private let cacheExpirationInterval: TimeInterval = 15_552_000 // 6 months (180 days)

    // MARK: - Init

    private init() {
        // Load cached templates on init
        loadCachedTemplates()
    }

    // MARK: - Computed Properties

    var templatesByCategory: [TemplateCategory: [PostcardTemplate]] {
        Dictionary(grouping: templates.compactMap { template -> (TemplateCategory, PostcardTemplate)? in
            guard let category = template.category else { return nil }
            return (category, template)
        }) { $0.0 }.mapValues { $0.map { $0.1 } }
    }

    var freeTemplates: [PostcardTemplate] {
        templates.filter { !$0.isPremium }
    }

    var premiumTemplates: [PostcardTemplate] {
        templates.filter { $0.isPremium }
    }

    var availableTemplates: [PostcardTemplate] {
        templates.filter { $0.isAvailable ?? !$0.isPremium }
    }

    // MARK: - Cache Management

    private func loadCachedTemplates() {
        if let data = UserDefaults.standard.data(forKey: templatesCacheKey),
           let cached = try? JSONDecoder().decode([PostcardTemplate].self, from: data) {
            templates = cached
        } else {
            // Use default templates as fallback
            templates = PostcardTemplate.defaultTemplates
        }
    }

    private func cacheTemplates(_ templates: [PostcardTemplate]) {
        if let data = try? JSONEncoder().encode(templates) {
            UserDefaults.standard.set(data, forKey: templatesCacheKey)
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: templatesCacheTimeKey)
        }
    }

    private var isCacheExpired: Bool {
        let lastCacheTime = UserDefaults.standard.double(forKey: templatesCacheTimeKey)
        guard lastCacheTime > 0 else { return true }
        return Date().timeIntervalSince1970 - lastCacheTime > cacheExpirationInterval
    }

    // MARK: - Fetch Postcards

    func fetchPostcards(refresh: Bool = false) async {
        if refresh {
            currentPage = 1
            hasMorePages = true
        }

        guard hasMorePages else { return }

        isLoading = true
        error = nil

        do {
            let response: PostcardsResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.postcardsMine)?page=\(currentPage)&limit=\(pageSize)"
            )

            if refresh {
                postcards = response.postcards
            } else {
                postcards.append(contentsOf: response.postcards)
            }

            totalCount = response.total
            hasMorePages = postcards.count < response.total
            currentPage += 1
        } catch {
            self.error = "Failed to load postcards: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Fetch Templates

    /// Fetches templates from API, with caching support
    /// - Parameter forceRefresh: If true, ignores cache and fetches from API
    func fetchTemplates(forceRefresh: Bool = false) async {
        // Return cached if not expired and not force refresh
        if !forceRefresh && !templates.isEmpty && !isCacheExpired {
            return
        }

        isLoadingTemplates = true
        error = nil

        do {
            // Try to fetch from API
            let fetchedTemplates: [PostcardTemplate] = try await APIClient.shared.request(
                endpoint: APIEndpoints.postcardTemplates
            )

            // Sort by sortOrder if available, otherwise by name
            let sorted = fetchedTemplates.sorted {
                if let order1 = $0.sortOrder, let order2 = $1.sortOrder {
                    return order1 < order2
                }
                return $0.name < $1.name
            }

            templates = sorted
            cacheTemplates(sorted)

            print("[PostcardsManager] Fetched \(sorted.count) templates from API")
        } catch {
            print("[PostcardsManager] Failed to fetch templates: \(error.localizedDescription)")

            // If we have no templates at all, use defaults
            if templates.isEmpty {
                templates = PostcardTemplate.defaultTemplates
                print("[PostcardsManager] Using \(templates.count) default templates")
            }
            // Keep existing cached templates if available
        }

        isLoadingTemplates = false
    }

    /// Ensures templates are loaded (from cache or API)
    func ensureTemplatesLoaded() async {
        if templates.isEmpty {
            loadCachedTemplates()
        }
        // Always try to refresh in background if cache is expired
        if isCacheExpired {
            await fetchTemplates()
        }
    }

    // MARK: - Create Postcard

    func createPostcard(from draft: PostcardDraft) async -> Postcard? {
        guard let request = draft.toCreateRequest() else {
            error = "Invalid postcard data"
            return nil
        }

        isLoading = true
        error = nil

        do {
            let response: PostcardResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.postcardsCreate,
                method: .post,
                body: request
            )

            // Add to beginning of list
            postcards.insert(response.postcard, at: 0)
            totalCount += 1

            isLoading = false
            return response.postcard
        } catch {
            self.error = "Failed to create postcard: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    // MARK: - Update Postcard

    func updatePostcard(id: String, request: UpdatePostcardRequest) async -> Bool {
        isLoading = true
        error = nil

        do {
            let response: PostcardResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.postcards)/\(id)",
                method: .patch,
                body: request
            )

            // Update in list
            if let index = postcards.firstIndex(where: { $0.id == id }) {
                postcards[index] = response.postcard
            }

            isLoading = false
            return true
        } catch {
            self.error = "Failed to update postcard: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Delete Postcard

    func deletePostcard(id: String) async -> Bool {
        isLoading = true
        error = nil

        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.postcards)/\(id)",
                method: .delete
            )

            // Remove from list
            postcards.removeAll { $0.id == id }
            totalCount -= 1

            isLoading = false
            return true
        } catch {
            self.error = "Failed to delete postcard: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }

    // MARK: - Share Postcard

    func sharePostcard(id: String, platform: SharePlatform) async -> SharePostcardResponse? {
        isLoading = true
        error = nil

        let request = SharePostcardRequest(platform: platform)

        do {
            let response: SharePostcardResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.postcards)/\(id)/share",
                method: .post,
                body: request
            )

            // Update share count locally
            if let index = postcards.firstIndex(where: { $0.id == id }) {
                var updatedPostcard = postcards[index]
                // Note: This creates a new struct with updated shareCount
                // In a real app, you might want to refetch or update differently
            }

            isLoading = false
            return response
        } catch {
            self.error = "Failed to share postcard: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    // MARK: - Generate Image

    func generatePostcardImage(from view: some View, size: CGSize) -> UIImage? {
        let controller = UIHostingController(rootView: view)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.backgroundColor = .clear

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    // MARK: - Clear Cache

    func clearCache() {
        postcards = []
        currentPage = 1
        totalCount = 0
        hasMorePages = true
    }
}

