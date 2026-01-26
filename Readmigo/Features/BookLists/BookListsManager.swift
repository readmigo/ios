import Foundation

@MainActor
class BookListsManager: ObservableObject {
    static let shared = BookListsManager()

    @Published var bookLists: [BookList] = []
    @Published var featuredLists: [BookList] = []
    @Published var aiPersonalizedList: BookList?
    @Published var categories: [Category] = []
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - Computed Properties

    var listsByType: [BookListType: [BookList]] {
        Dictionary(grouping: bookLists, by: { $0.type })
    }

    var editorsPicks: [BookList] {
        bookLists.filter { $0.type == .editorsPick }
    }

    var topRanked: [BookList] {
        bookLists.filter { $0.type == .ranking }
    }

    var rootCategories: [Category] {
        categories.filter { $0.parentId == nil }
    }

    // MARK: - Fetch Book Lists

    func fetchBookLists(
        type: BookListType? = nil,
        page: Int = 1,
        limit: Int = 20
    ) async {
        isLoading = true
        error = nil

        var endpoint = "\(APIEndpoints.booklists)?page=\(page)&limit=\(limit)"
        if let type = type {
            endpoint += "&type=\(type.rawValue)"
        }

        do {
            let response: BookListsResponse = try await APIClient.shared.request(endpoint: endpoint)

            if page == 1 {
                bookLists = response.data
            } else {
                bookLists.append(contentsOf: response.data)
            }

            // Separate featured lists
            featuredLists = bookLists.filter {
                $0.type == .editorsPick || $0.type == .aiFeatured
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Fetch Book List Detail

    func fetchBookList(id: String) async -> BookList? {
        do {
            return try await APIClient.shared.request(
                endpoint: APIEndpoints.booklist(id)
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Fetch AI Personalized List

    func fetchAIPersonalizedList() async {
        do {
            aiPersonalizedList = try await APIClient.shared.request(
                endpoint: APIEndpoints.booklistsAIPersonalized
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Categories

    func fetchCategories() async {
        do {
            // Fetch hierarchical category tree
            let treeCategories: [Category] = try await APIClient.shared.request(
                endpoint: APIEndpoints.categoriesTree
            )
            categories = treeCategories
        } catch {
            // Fallback to flat list if tree endpoint fails
            do {
                let response: CategoriesResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.categories
                )
                categories = response.categories
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Fetch Category by ID

    func fetchCategory(id: String) async -> Category? {
        do {
            return try await APIClient.shared.request(
                endpoint: APIEndpoints.category(id)
            )
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    // MARK: - Fetch Subcategories

    func fetchSubcategories(parentId: String) async -> [Category] {
        do {
            return try await APIClient.shared.request(
                endpoint: APIEndpoints.categoryChildren(parentId)
            )
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    // MARK: - Fetch Books in Category

    func fetchBooks(inCategory categoryId: String, page: Int = 1, limit: Int = 20) async -> [Book] {
        do {
            let response: CategoryBooksResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.categoryBooks(categoryId))?page=\(page)&limit=\(limit)"
            )
            return response.books
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    // MARK: - Refresh All

    func refreshAll() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchBookLists() }
            group.addTask { await self.fetchCategories() }
            group.addTask { await self.fetchAIPersonalizedList() }
        }

        isLoading = false
    }
}
