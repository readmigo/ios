import Foundation
import SwiftUI

// MARK: - Discover ViewModel

@MainActor
final class DiscoverViewModel: ObservableObject {
    // MARK: - Singleton

    static let shared = DiscoverViewModel()

    // MARK: - Published Properties

    /// Tabs from backend
    @Published var tabs: [DiscoverTab] = []

    /// Currently selected tab ID
    @Published var selectedTabId: String = ""

    /// Books for each tab (lazy loaded)
    @Published private(set) var tabBooks: [String: [BookWithScore]] = [:]

    /// Loading state per tab
    @Published private(set) var tabLoadingStates: [String: Bool] = [:]

    /// Has more pages per tab
    @Published private(set) var tabHasMore: [String: Bool] = [:]

    /// Current page per tab
    @Published private(set) var tabCurrentPages: [String: Int] = [:]

    /// Error state
    @Published var error: Error?

    /// Is loading tabs
    @Published private(set) var isLoadingTabs = false

    /// Whether initial data has been loaded from cache
    @Published private(set) var hasLoadedFromCache = false

    // MARK: - Private Properties

    private let pageSize = 20
    private let cacheService = ResponseCacheService.shared

    /// Active loading tasks (kept alive to prevent cancellation when view disappears)
    private var loadingTasks: [String: Task<Void, Never>] = [:]

    /// Desired tab order for category tabs (by slug)
    /// Order: 小说-经典文学-戏剧-哲学-诗歌-冒险-浪漫-其他
    private let tabSortOrder: [String] = [
        "fiction",
        "classics",
        "drama",
        "philosophy",
        "poetry",
        "adventure",
        "romance",
        "other"
    ]

    /// Sort tabs according to desired order
    /// - Parameter tabs: Tabs from backend
    /// - Returns: Sorted tabs with recommendation tab first, then categories in desired order
    private func sortTabs(_ tabs: [DiscoverTab]) -> [DiscoverTab] {
        return tabs.sorted { tab1, tab2 in
            // Recommendation tab always comes first
            if tab1.type == .recommendation && tab2.type != .recommendation {
                return true
            }
            if tab1.type != .recommendation && tab2.type == .recommendation {
                return false
            }

            // Both are recommendation tabs - use sortOrder from backend
            if tab1.type == .recommendation && tab2.type == .recommendation {
                return tab1.sortOrder < tab2.sortOrder
            }

            // Both are category tabs - use custom sort order
            let index1 = tabSortOrder.firstIndex(of: tab1.slug.lowercased()) ?? Int.max
            let index2 = tabSortOrder.firstIndex(of: tab2.slug.lowercased()) ?? Int.max

            if index1 != index2 {
                return index1 < index2
            }

            // Fallback to backend sortOrder for unknown slugs
            return tab1.sortOrder < tab2.sortOrder
        }
    }

    // MARK: - Computed Properties

    /// Currently selected tab
    var selectedTab: DiscoverTab? {
        tabs.first { $0.id == selectedTabId }
    }

    /// Books for current tab
    var currentBooks: [BookWithScore] {
        tabBooks[selectedTabId] ?? []
    }

    /// Is current tab loading
    var isCurrentTabLoading: Bool {
        tabLoadingStates[selectedTabId] ?? false
    }

    /// Does current tab have more pages
    var hasMorePages: Bool {
        tabHasMore[selectedTabId] ?? true
    }

    // MARK: - Public Methods

    /// Load tabs - first from cache (instant), then refresh from network (background)
    func loadTabs() async {
        guard !isLoadingTabs else {
            LoggingService.shared.debug(.books, "📋 loadTabs: skipped (already loading)", component: "DiscoverViewModel")
            return
        }

        // Step 1: Try to load from cache first for instant display
        if !hasLoadedFromCache {
            await loadFromCache()
        }

        // Step 2: Fetch from network in background to refresh data
        isLoadingTabs = true
        error = nil
        LoggingService.shared.debug(.books, "📋 loadTabs: fetching from network", component: "DiscoverViewModel")

        do {
            let fetchedTabs = try await APIClient.shared.getDiscoverTabs()
            let sortedTabs = sortTabs(fetchedTabs)

            // Cache the tabs
            await cacheService.set(sortedTabs, for: CacheKeys.discoverTabsKey(), ttl: .categories)

            tabs = sortedTabs
            LoggingService.shared.debug(.books, "📋 loadTabs: fetched \(fetchedTabs.count) tabs, sorted by custom order", component: "DiscoverViewModel")

            // Set default selected tab if not set
            if selectedTabId.isEmpty, let firstTab = tabs.first {
                selectedTabId = firstTab.id
                LoggingService.shared.debug(.books, "📋 loadTabs: selected first tab: \(firstTab.id)", component: "DiscoverViewModel")
            }

            // Load content for selected tab (spawn independent task to prevent cancellation)
            if !selectedTabId.isEmpty {
                let tabId = selectedTabId
                loadingTasks[tabId] = Task { [weak self] in
                    await self?.loadTabContentInternal(tabId: tabId)
                }
            }
        } catch {
            // Only show error if we don't have cached data
            if tabs.isEmpty {
                self.error = error
            }
            LoggingService.shared.debug(.books, "📋 loadTabs: FAILED - \(error)", component: "DiscoverViewModel")
            LoggingService.shared.error(.books, "Failed to load discover tabs: \(error)")
        }

        isLoadingTabs = false
        LoggingService.shared.debug(.books, "📋 loadTabs: completed, tabs=\(tabs.count), selectedTabId=\(selectedTabId)", component: "DiscoverViewModel")
    }

    /// Load data from persistent cache for instant startup
    private func loadFromCache() async {
        LoggingService.shared.debug(.books, "Loading discover data from cache", component: "DiscoverViewModel")

        let tabsCacheKey = CacheKeys.discoverTabsKey()

        // Load cached tabs
        if let cachedTabs: [DiscoverTab] = await cacheService.get(tabsCacheKey, type: [DiscoverTab].self) {
            tabs = cachedTabs
            LoggingService.shared.info(.books, "Loaded \(cachedTabs.count) tabs from cache", component: "DiscoverViewModel")

            // Set default selected tab
            if selectedTabId.isEmpty, let firstTab = tabs.first {
                selectedTabId = firstTab.id
            }

            // Load cached books for selected tab
            if !selectedTabId.isEmpty {
                let tab = tabs.first { $0.id == selectedTabId }
                let categoryId = tab?.categoryId
                let cacheKey = CacheKeys.discoverBooksKey(categoryId: categoryId)

                if let cachedBooks: DiscoverBooksResponse = await cacheService.get(cacheKey, type: DiscoverBooksResponse.self) {
                    tabBooks[selectedTabId] = cachedBooks.books
                    tabCurrentPages[selectedTabId] = 1
                    tabHasMore[selectedTabId] = cachedBooks.hasMore
                    LoggingService.shared.info(.books, "Loaded \(cachedBooks.books.count) books from cache for tab \(selectedTabId)", component: "DiscoverViewModel")
                } else {
                    LoggingService.shared.debug(.books, "No cached books found for tab \(selectedTabId)", component: "DiscoverViewModel")
                }
            }
        } else {
            LoggingService.shared.debug(.books, "No cached tabs found", component: "DiscoverViewModel")
        }

        hasLoadedFromCache = true
    }

    /// Select a tab and load its content if needed
    func selectTab(_ tabId: String) async {
        LoggingService.shared.debug(.books, "📋 selectTab: called with tabId=\(tabId), current=\(selectedTabId)", component: "DiscoverViewModel")

        // Update selected tab ID for UI
        selectedTabId = tabId

        // Check if we need to load content
        let existingBooks = tabBooks[tabId]
        let needsLoad = existingBooks == nil

        LoggingService.shared.debug(.books, "📋 selectTab: existingBooks=\(existingBooks?.count ?? -1), needsLoad=\(needsLoad)", component: "DiscoverViewModel")

        if needsLoad {
            // Spawn independent task to prevent cancellation when view disappears
            loadingTasks[tabId] = Task { [weak self] in
                await self?.loadTabContentInternal(tabId: tabId)
            }
        }
    }

    /// Load content for a specific tab (spawns independent task)
    func loadTabContent(tabId: String) {
        // Spawn independent task to prevent cancellation when view disappears
        loadingTasks[tabId] = Task { [weak self] in
            await self?.loadTabContentInternal(tabId: tabId)
        }
    }

    /// Internal implementation for loading tab content
    private func loadTabContentInternal(tabId: String) async {
        // Skip if already loading
        guard tabLoadingStates[tabId] != true else {
            LoggingService.shared.debug(.books, "📚 loadTabContent: skipped (already loading for \(tabId))", component: "DiscoverViewModel")
            return
        }

        tabLoadingStates[tabId] = true
        LoggingService.shared.debug(.books, "📚 loadTabContent: started for tabId=\(tabId)", component: "DiscoverViewModel")

        defer {
            tabLoadingStates[tabId] = false
            loadingTasks.removeValue(forKey: tabId)
        }

        let tab = tabs.first { $0.id == tabId }
        let categoryId = tab?.categoryId
        let cacheKey = CacheKeys.discoverBooksKey(categoryId: categoryId)

        // Try to load from cache first if we don't have data
        if tabBooks[tabId] == nil {
            if let cachedBooks: DiscoverBooksResponse = await cacheService.get(cacheKey, type: DiscoverBooksResponse.self) {
                tabBooks[tabId] = cachedBooks.books
                tabCurrentPages[tabId] = 1
                tabHasMore[tabId] = cachedBooks.hasMore
                LoggingService.shared.debug(.books, "📚 loadTabContent: loaded \(cachedBooks.books.count) books from cache for tab \(tabId)", component: "DiscoverViewModel")
            }
        }

        do {
            LoggingService.shared.debug(.books, "📚 loadTabContent: fetching books for categoryId=\(categoryId ?? "nil")", component: "DiscoverViewModel")

            let response = try await APIClient.shared.getDiscoverBooks(
                categoryId: categoryId,
                page: 1,
                pageSize: pageSize
            )

            // Cache the response
            await cacheService.set(response, for: cacheKey, ttl: .bookList)

            tabBooks[tabId] = response.books
            tabCurrentPages[tabId] = 1
            tabHasMore[tabId] = response.hasMore

            // Check cover URLs
            let booksWithCovers = response.books.filter { $0.book.coverUrl != nil && !($0.book.coverUrl?.isEmpty ?? true) }
            LoggingService.shared.debug(.books, "📚 loadTabContent: loaded \(response.books.count) books, \(booksWithCovers.count) with covers", component: "DiscoverViewModel")
        } catch {
            // Ignore cancellation errors - they're expected when navigating away
            if Task.isCancelled {
                LoggingService.shared.debug(.books, "📚 loadTabContent: cancelled (expected during navigation)", component: "DiscoverViewModel")
                return
            }
            // Only show error if we don't have cached data
            if tabBooks[tabId] == nil || tabBooks[tabId]?.isEmpty == true {
                LoggingService.shared.debug(.books, "📚 loadTabContent: FAILED - \(error)", component: "DiscoverViewModel")
                LoggingService.shared.error(.books, "Failed to load tab content: \(error)")
                self.error = error
            } else {
                LoggingService.shared.debug(.books, "📚 loadTabContent: network failed but using cached data", component: "DiscoverViewModel")
            }
        }
    }

    /// Load more books for current tab
    func loadMoreBooks() async {
        await loadMoreBooks(for: selectedTabId)
    }

    /// Load more books for a specific tab
    func loadMoreBooks(for tabId: String?) async {
        guard let tabId, !tabId.isEmpty else { return }
        guard tabLoadingStates[tabId] != true else { return }
        guard let hasMore = tabHasMore[tabId], hasMore else { return }
        guard let currentPage = tabCurrentPages[tabId] else { return }

        tabLoadingStates[tabId] = true

        do {
            let nextPage = currentPage + 1
            let tab = tabs.first { $0.id == tabId }
            let categoryId = tab?.categoryId

            let response = try await APIClient.shared.getDiscoverBooks(
                categoryId: categoryId,
                page: nextPage,
                pageSize: pageSize
            )

            // Append new books
            var existingBooks = tabBooks[tabId] ?? []
            existingBooks.append(contentsOf: response.books)
            tabBooks[tabId] = existingBooks

            tabCurrentPages[tabId] = nextPage
            tabHasMore[tabId] = response.hasMore
        } catch {
            LoggingService.shared.error(.books, "Failed to load more books: \(error)")
            self.error = error
        }

        tabLoadingStates[tabId] = false
    }

    /// Refresh current tab content
    func refresh() async {
        LoggingService.shared.debug(.books, "🔄 refresh: called, tabs=\(tabs.count), selectedTabId=\(selectedTabId)", component: "DiscoverViewModel")

        // If tabs are empty or selectedTabId is empty, reload everything
        if tabs.isEmpty || selectedTabId.isEmpty {
            LoggingService.shared.debug(.books, "🔄 refresh: tabs empty or no selection, calling refreshAll()", component: "DiscoverViewModel")
            await refreshAll()
            return
        }

        await refreshTab(tabId: selectedTabId)
        LoggingService.shared.debug(.books, "🔄 refresh: completed, currentBooks=\(currentBooks.count)", component: "DiscoverViewModel")
    }

    /// Refresh all tabs
    func refreshAll() async {
        LoggingService.shared.debug(.books, "🔄 refreshAll: started", component: "DiscoverViewModel")

        // Use withCheckedContinuation to spawn an independent task that won't be cancelled
        await withCheckedContinuation { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                await MainActor.run {
                    self.tabBooks.removeAll()
                    self.tabCurrentPages.removeAll()
                    self.tabHasMore.removeAll()
                    self.tabs.removeAll()
                    self.selectedTabId = ""
                }

                await self.loadTabs()
                LoggingService.shared.debug(.books, "🔄 refreshAll: completed, tabs=\(self.tabs.count), currentBooks=\(self.currentBooks.count)", component: "DiscoverViewModel")
                continuation.resume()
            }
        }
    }

    /// Refresh a specific tab
    func refreshTab(tabId: String) async {
        guard !tabId.isEmpty else { return }

        await withCheckedContinuation { continuation in
            Task { [weak self] in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                await MainActor.run {
                    self.tabBooks[tabId] = nil
                    self.tabCurrentPages[tabId] = nil
                    self.tabHasMore[tabId] = true
                }

                await self.loadTabContentInternal(tabId: tabId)
                continuation.resume()
            }
        }
    }
}
