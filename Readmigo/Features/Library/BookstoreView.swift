import SwiftUI
import Kingfisher
import Combine

struct BookstoreView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @ObservedObject private var viewModel = BookstoreViewModel.shared
    @StateObject private var searchHistoryManager = SearchHistoryManager.shared
    @State private var searchText = ""
    @State private var unifiedSearchResult: UnifiedSearchResponse?
    @State private var isSearching = false
    @State private var isSearchFocused = false
    @State private var popularSearches: [PopularSearch] = []
    // Autocomplete suggestions
    @State private var suggestions: [SearchSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var suggestionTask: Task<Void, Never>?
    // Tab paging & scroll-to-top coordination
    @State private var pagerSelection = 0
    @State private var scrollSignals: [String: Int] = [:]
    // Tab double-tap notification
    private let tabDoubleTapPublisher = NotificationCenter.default.publisher(for: .bookstoreTabDoubleTapped)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                SearchBar(
                    text: $searchText,
                    isFocused: $isSearchFocused,
                    onSearch: performSearch,
                    onTextChange: onSearchTextChange
                )
                .padding(.vertical, 8)

                // Content: Search or Discover
                if isSearchFocused || !searchText.isEmpty {
                    // Search mode
                    if !searchText.isEmpty && (isSearching || unifiedSearchResult != nil) {
                        searchResultsContent
                    } else {
                        searchAssistContent
                    }
                } else {
                    // Tab Bar (sticky, outside ScrollView)
                    BookstoreTabBar(
                            tabs: viewModel.tabs,
                            selectedTabId: $viewModel.selectedTabId,
                            onTabSelected: { tabId in
                                // Align pager index with tapped tab
                                if let index = viewModel.tabs.firstIndex(where: { $0.id == tabId }) {
                                    pagerSelection = index
                                }
                                triggerScrollToTop(for: tabId)
                                Task {
                                    await viewModel.selectTab(tabId)
                                }
                            }
                        )
                        .background(Color(.systemBackground))

                    // Discover tabs content
                    bookstoreTabsContent
                }
            }
            .navigationTitle("tab.discover".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // Load discover tabs
            if viewModel.tabs.isEmpty {
                await viewModel.loadTabs()
            }
            // Load popular searches
            if popularSearches.isEmpty {
                await loadPopularSearches()
            }
        }
        .onReceive(tabDoubleTapPublisher) { _ in
            triggerScrollToTop(for: viewModel.selectedTabId)
        }
        .onChange(of: viewModel.selectedTabId) { _, newValue in
            syncPagerSelection(with: newValue)
        }
        .onChange(of: viewModel.tabs) { _, _ in
            syncPagerSelection(with: viewModel.selectedTabId)
        }
    }

    // MARK: - Search Logic

    private func performSearch() {
        guard !searchText.isEmpty else {
            unifiedSearchResult = nil
            return
        }

        // Save to history
        searchHistoryManager.addSearch(searchText)

        isSearching = true
        Task {
            do {
                unifiedSearchResult = try await APIClient.shared.unifiedSearch(
                    query: searchText,
                    limit: 5
                )
            } catch {
                LoggingService.shared.debug(.books, "Search error: \(error)", component: "BookstoreView")
                unifiedSearchResult = nil
            }
            isSearching = false
        }
    }

    private func loadPopularSearches() async {
        let cacheKey = CacheKeys.popularSearchesKey()
        let cacheService = ResponseCacheService.shared

        do {
            popularSearches = try await APIClient.shared.getPopularSearches(limit: 8)
            // Cache the response
            await cacheService.set(popularSearches, for: cacheKey, ttl: .search)
        } catch {
            // Try to load from cache on network failure
            if let cached: [PopularSearch] = await cacheService.get(cacheKey, type: [PopularSearch].self) {
                popularSearches = cached
                LoggingService.shared.info(.books, "Loaded popular searches from cache")
            } else {
                LoggingService.shared.debug(.books, "Failed to load popular searches: \(error)", component: "BookstoreView")
            }
        }
    }

    private func onSearchTextChange(_ text: String) {
        // Cancel previous task
        suggestionTask?.cancel()

        // Clear suggestions if text is too short
        guard text.count >= 2 else {
            suggestions = []
            return
        }

        // Debounce: wait 300ms before fetching suggestions
        suggestionTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                guard !Task.isCancelled else { return }

                await fetchSuggestions(for: text)
            } catch {
                // Task was cancelled, ignore
            }
        }
    }

    @MainActor
    private func fetchSuggestions(for query: String) async {
        isLoadingSuggestions = true
        defer { isLoadingSuggestions = false }

        do {
            suggestions = try await APIClient.shared.getSearchSuggestions(query: query, limit: 5)
        } catch {
            LoggingService.shared.debug(.books, "Failed to fetch suggestions: \(error)", component: "BookstoreView")
            suggestions = []
        }
    }

    // MARK: - Content Builders

    @ViewBuilder
    private var searchAssistContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !searchHistoryManager.history.isEmpty {
                    SearchHistorySection(
                        history: searchHistoryManager.history,
                        onSelect: { query in
                            searchText = query
                            performSearch()
                        },
                        onRemove: { query in
                            searchHistoryManager.removeSearch(query)
                        },
                        onClearAll: {
                            searchHistoryManager.clearHistory()
                        }
                    )
                }
            }
            .padding(.bottom)
        }
    }

    @ViewBuilder
    private var bookstoreTabsContent: some View {
        if viewModel.tabs.isEmpty {
            VStack(spacing: 16) {
                if viewModel.isLoadingTabs {
                    ProgressView()
                    Text("common.loading".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "books.vertical")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("discover.empty".localized)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            TabView(selection: $pagerSelection) {
                ForEach(Array(viewModel.tabs.enumerated()), id: \.element.id) { index, tab in
                    BookstoreTabPage(
                        tab: tab,
                        viewModel: viewModel,
                        scrollSignal: scrollSignals[tab.id, default: 0]
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.interactiveSpring(), value: pagerSelection)
            .onChange(of: pagerSelection) { _, newValue in
                guard viewModel.tabs.indices.contains(newValue) else { return }
                let tabId = viewModel.tabs[newValue].id
                if viewModel.selectedTabId != tabId {
                    Task {
                        await viewModel.selectTab(tabId)
                    }
                } else {
                    triggerScrollToTop(for: tabId)
                }
            }
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isSearching {
                    ProgressView("search.searching".localized)
                        .padding(40)
                } else if let result = unifiedSearchResult {
                    CategorizedSearchResultsSection(
                        result: result,
                        onAuthorTap: { _ in },
                        onBookTap: { _ in },
                        onQuoteTap: { _ in }
                    )
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("search.noResults".localized)
                            .foregroundColor(.secondary)
                    }
                    .padding(40)
                }
            }
            .padding(.bottom)
        }
    }

    private func triggerScrollToTop(for tabId: String) {
        guard !tabId.isEmpty else { return }
        scrollSignals[tabId, default: 0] += 1
    }

    private func syncPagerSelection(with tabId: String) {
        guard let index = viewModel.tabs.firstIndex(where: { $0.id == tabId }) else { return }
        if pagerSelection != index {
            pagerSelection = index
        }
    }
}

// MARK: - Discover Tab Page

private struct BookstoreTabPage: View {
    let tab: BookstoreTab
    @ObservedObject var viewModel: BookstoreViewModel
    let scrollSignal: Int

    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id(scrollAnchor)

                    tabContent
                }
                .padding(.bottom)
            }
            .elegantRefreshable {
                await viewModel.refreshTab(tabId: tab.id)
            }
            .onAppear {
                scrollProxy = proxy
                if viewModel.tabBooks[tab.id] == nil {
                    viewModel.loadTabContent(tabId: tab.id)
                }
            }
            .onChange(of: scrollSignal) { _, _ in
                guard let scrollProxy else { return }
                withAnimation(.easeOut(duration: 0.25)) {
                    scrollProxy.scrollTo(scrollAnchor, anchor: .top)
                }
            }
        }
    }

    private var scrollAnchor: String {
        "scrollTop-\(tab.id)"
    }

    @ViewBuilder
    private var tabContent: some View {
        let books = viewModel.tabBooks[tab.id] ?? []
        let isLoading = viewModel.tabLoadingStates[tab.id] ?? false
        let hasMore = viewModel.tabHasMore[tab.id] ?? true

        if viewModel.isLoadingTabs && books.isEmpty {
            loadingView
        } else if books.isEmpty && !isLoading {
            emptyView
        } else {
            bookListView(
                books: books,
                hasMore: hasMore,
                isLoading: isLoading
            )
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("common.loading".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("discover.empty".localized)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    @ViewBuilder
    private func bookListView(
        books: [BookWithScore],
        hasMore: Bool,
        isLoading: Bool
    ) -> some View {
        ForEach(Array(books.enumerated()), id: \.element.id) { index, bookWithScore in
            BookstoreBookRow(bookWithScore: bookWithScore)
                .padding(.horizontal)
                .padding(.vertical, 8)

            if index < books.count - 1 {
                Divider()
                    .padding(.horizontal)
            }
        }

        if hasMore {
            Button {
                Task {
                    await viewModel.loadMoreBooks(for: tab.id)
                }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text("common.loadMore".localized)
                        Image(systemName: "arrow.down.circle")
                    }
                }
                .foregroundColor(.accentColor)
                .padding()
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Book List Feed Card

private struct BookListFeedCard: View {
    let list: BookList

    var body: some View {
        NavigationLink {
            BookListDetailView(bookListId: list.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Header with type badge
                HStack {
                    Image(systemName: list.type.icon)
                        .foregroundColor(typeColor)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(list.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(list.type.displayName)
                                .font(.caption)
                                .foregroundColor(typeColor)

                            Text("•")
                                .foregroundColor(.secondary)

                            Text("discover.booksCount".localized(with: list.bookCount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Book previews
                if let books = list.books, !books.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(books.prefix(6))) { book in
                                BookListPreviewCover(book: book)
                            }

                            if books.count > 6 {
                                VStack {
                                    Text("+\(books.count - 6)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                                .frame(width: 50, height: 75)
                                .background(Color(.systemGray5))
                                .cornerRadius(6)
                            }
                        }
                    }
                }

                // Description if available
                if let description = list.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var typeColor: Color {
        switch list.type {
        case .editorsPick: return .yellow
        case .annualBest: return .orange
        case .university: return .blue
        case .celebrity: return .purple
        case .ranking: return .red
        case .collection: return .green
        case .aiRecommended, .aiFeatured: return .cyan
        case .personalized: return .pink
        }
    }
}

private struct BookListPreviewCover: View {
    let book: Book

    var body: some View {
        if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
            KFImage(url)
                .placeholder { _ in coverPlaceholder }
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 50, height: 75)
                .cornerRadius(6)
        } else {
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 75)
            .cornerRadius(6)
            .overlay(
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Book Feed Card

private struct BookFeedCard: View {
    let book: Book

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in coverPlaceholder }
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
            } else {
                coverPlaceholder
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Genre tags (no difficulty badge in book lists)
                    if !book.localizedGenres.isEmpty {
                        Text(book.localizedGenres.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    #if DEBUG
                    // Source badge (debug only)
                    if let source = book.source, !source.isEmpty {
                        Spacer(minLength: 4)
                        SourceBadgeView(source: source)
                    }
                    #endif
                }

                // Book info summary (genres + word count + subjects)
                let infoComponents = buildBookInfoComponents(book: book)
                if !infoComponents.isEmpty {
                    Text(infoComponents.joined(separator: " · "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 60, height: 90)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.gray)
            )
    }

    /// Build book info components for display (genres + word count + subjects)
    private func buildBookInfoComponents(book: Book) -> [String] {
        var components: [String] = []

        // Add first genre if available (already shown in tags, so skip if duplicated)
        // We'll use subjects instead for more variety

        // Add word count
        if let wordCount = book.wordCount {
            if wordCount >= 10000 {
                let formatted = wordCount >= 10000 ? "\(wordCount / 10000)万字" : "\(wordCount)字"
                components.append(formatted)
            } else if wordCount >= 1000 {
                components.append("\(wordCount / 1000)k words")
            }
        }

        // Add subjects (first 2, excluding duplicates with genres)
        if let subjects = book.subjects, !subjects.isEmpty {
            let genreSet = Set((book.genres ?? []).map { $0.lowercased() })
            let filteredSubjects = subjects
                .filter { !genreSet.contains($0.lowercased()) }
                .prefix(2)
            if !filteredSubjects.isEmpty {
                components.append(contentsOf: filteredSubjects)
            }
        }

        return components
    }
}

// MARK: - Discover Book Row (with favorite button outside NavigationLink)

private struct BookstoreBookRow: View {
    let bookWithScore: BookWithScore
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var isFavorited: Bool = false
    @State private var navigateToDetail: Bool = false

    private var book: Book { bookWithScore.book }

    var body: some View {
        HStack(spacing: 12) {
            // Book info (tappable for navigation)
            HStack(spacing: 12) {
                // Cover
                if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                    KFImage(url)
                        .placeholder { _ in coverPlaceholder }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 60, height: 90)
                        .cornerRadius(8)
                } else {
                    coverPlaceholder
                }

                // Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text(book.localizedAuthor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Genre tags
                    if !book.localizedGenres.isEmpty {
                        Text(book.localizedGenres.prefix(2).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToDetail = true
            }

            // Favorite button
            Image(systemName: isFavorited ? "heart.fill" : "heart")
                .font(.system(size: 22))
                .foregroundColor(isFavorited ? .red : .gray)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    LoggingService.shared.debug(.books, "❤️ [BookstoreBookRow] Heart tapped! bookId: \(book.id)", component: "BookstoreView")
                    LoggingService.shared.debug(.books, "❤️ [BookstoreBookRow] Current isFavorited: \(isFavorited)", component: "BookstoreView")
                    Task {
                        LoggingService.shared.debug(.books, "❤️ [BookstoreBookRow] Calling toggleFavorite...", component: "BookstoreView")
                        let success = await favoritesManager.toggleFavorite(bookId: book.id)
                        LoggingService.shared.debug(.books, "❤️ [BookstoreBookRow] toggleFavorite returned: \(success)", component: "BookstoreView")
                        if success {
                            isFavorited.toggle()
                            LoggingService.shared.debug(.books, "❤️ [BookstoreBookRow] isFavorited toggled to: \(isFavorited)", component: "BookstoreView")
                        }
                    }
                }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            isFavorited = favoritesManager.isFavorited(bookId: book.id)
        }
        .background(
            NavigationLink(destination: BookDetailView(book: book), isActive: $navigateToDetail) {
                EmptyView()
            }
            .opacity(0)
        )
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 60, height: 90)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Difficulty Tag

private struct DifficultyTag: View {
    let score: Double

    var level: DifficultyLevel {
        switch score {
        case 0..<30: return .easy
        case 30..<50: return .medium
        case 50..<70: return .challenging
        default: return .advanced
        }
    }

    var body: some View {
        Text(level.localizedName)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Difficulty Level Enum

enum DifficultyLevel: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case challenging = "Challenging"
    case advanced = "Advanced"

    var localizedName: String {
        switch self {
        case .easy: return "difficulty.easy".localized
        case .medium: return "difficulty.medium".localized
        case .challenging: return "difficulty.challenging".localized
        case .advanced: return "difficulty.advanced".localized
        }
    }

    var range: ClosedRange<Double> {
        switch self {
        case .easy: return 0...29
        case .medium: return 30...49
        case .challenging: return 50...69
        case .advanced: return 70...100
        }
    }

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .blue
        case .challenging: return .orange
        case .advanced: return .red
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    var isFocused: Binding<Bool>?
    let onSearch: () -> Void
    var onTextChange: ((String) -> Void)?
    @FocusState private var textFieldFocused: Bool

    init(
        text: Binding<String>,
        isFocused: Binding<Bool>? = nil,
        onSearch: @escaping () -> Void,
        onTextChange: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.isFocused = isFocused
        self.onSearch = onSearch
        self.onTextChange = onTextChange
    }

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("search.placeholder".localized, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($textFieldFocused)
                .onSubmit(onSearch)
                .onChange(of: text) { _, newValue in
                    onTextChange?(newValue)
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    onTextChange?("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .onChange(of: textFieldFocused) { _, newValue in
            isFocused?.wrappedValue = newValue
        }
        .onTapGesture {
            textFieldFocused = true
        }
    }
}

// MARK: - Search History Section

struct SearchHistorySection: View {
    let history: [String]
    let onSelect: (String) -> Void
    let onRemove: (String) -> Void
    let onClearAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("search.recentSearches".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button("common.clearAll".localized) {
                    onClearAll()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            // History items
            ForEach(history, id: \.self) { query in
                SearchHistoryRow(
                    query: query,
                    onSelect: { onSelect(query) },
                    onRemove: { onRemove(query) }
                )
            }
        }
        .background(Color(.systemBackground))
    }
}

private struct SearchHistoryRow: View {
    let query: String
    let onSelect: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(query)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()
                }
            }
            .buttonStyle(.plain)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - Genre Filter (kept for BrowseBooksView)

struct GenreFilterSection: View {
    let genres: [String]
    @Binding var selectedGenre: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("discover.genres".localized)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    FilterChip(
                        title: "common.all".localized,
                        isSelected: selectedGenre == nil
                    ) {
                        selectedGenre = nil
                    }

                    ForEach(genres, id: \.self) { genre in
                        FilterChip(
                            title: genre,
                            isSelected: selectedGenre == genre
                        ) {
                            selectedGenre = genre
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .cornerRadius(20)
        }
    }
}

// MARK: - Difficulty Filter (kept for BrowseBooksView)

struct DifficultyFilterSection: View {
    @Binding var selectedDifficulty: DifficultyLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("discover.difficulty".localized)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal)

            HStack(spacing: 10) {
                DifficultyChip(
                    level: nil,
                    isSelected: selectedDifficulty == nil
                ) {
                    selectedDifficulty = nil
                }

                ForEach(DifficultyLevel.allCases, id: \.self) { level in
                    DifficultyChip(
                        level: level,
                        isSelected: selectedDifficulty == level
                    ) {
                        selectedDifficulty = level
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DifficultyChip: View {
    let level: DifficultyLevel?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(level?.localizedName ?? "common.all".localized)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : (level?.color ?? .primary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? (level?.color ?? .blue) : (level?.color.opacity(0.15) ?? Color(.systemGray5)))
                .cornerRadius(16)
        }
    }
}

// MARK: - Featured Book Lists Section

struct FeaturedBookListsSection: View {
    let lists: [BookList]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("discover.curatedLists".localized)
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink {
                    BookListsView()
                } label: {
                    Text("common.seeAll".localized)
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(lists) { list in
                        NavigationLink {
                            BookListDetailView(bookListId: list.id)
                        } label: {
                            FeaturedListCard(list: list)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct FeaturedListCard: View {
    let list: BookList

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Image or Gradient (with Kingfisher caching)
            ZStack {
                if let coverUrl = list.coverUrl, !coverUrl.isEmpty, let url = URL(string: coverUrl) {
                    KFImage(url)
                        .placeholder { _ in listGradient }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    listGradient
                }

                // Type Badge
                VStack {
                    HStack {
                        Spacer()
                        Text(list.type.displayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(8)
            }
            .frame(width: 160, height: 100)
            .cornerRadius(12)

            Text(list.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)

            Text("discover.booksCount".localized(with: list.bookCount))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 160)
    }

    private var listGradient: some View {
        LinearGradient(
            colors: [.blue.opacity(0.7), .purple.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "books.vertical.fill")
                .font(.title)
                .foregroundColor(.white.opacity(0.5))
        )
    }
}

// MARK: - Popular Searches Section

struct PopularSearchesSection: View {
    let searches: [PopularSearch]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                Text("search.popular".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Grid of popular searches
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(Array(searches.enumerated()), id: \.element.id) { index, search in
                    PopularSearchRow(
                        rank: index + 1,
                        search: search,
                        onTap: { onSelect(search.term) }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 16)
    }
}

private struct PopularSearchRow: View {
    let rank: Int
    let search: PopularSearch
    let onTap: () -> Void

    private var rankColor: Color {
        switch rank {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("\(rank)")
                    .font(.caption.bold())
                    .foregroundColor(rankColor)
                    .frame(width: 20)
                Text(search.term)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Categorized Search Results Section

struct CategorizedSearchResultsSection: View {
    let result: UnifiedSearchResponse
    let onAuthorTap: (SearchAuthor) -> Void
    let onBookTap: (SearchBook) -> Void
    let onQuoteTap: (SearchQuote) -> Void

    var body: some View {
        if result.isEmpty {
            // No results
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("search.noResults".localized)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
        } else {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Authors Section
                if !result.authors.items.isEmpty {
                    SearchCategoryHeader(
                        title: "search.authors".localized,
                        icon: "person.fill",
                        count: result.authors.total,
                        hasMore: result.authors.hasMore
                    )

                    ForEach(result.authors.items) { author in
                        NavigationLink {
                            AuthorProfileView(authorId: author.id)
                        } label: {
                            AuthorSearchResultRow(author: author)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Books Section
                if !result.books.items.isEmpty {
                    SearchCategoryHeader(
                        title: "search.books".localized,
                        icon: "book.fill",
                        count: result.books.total,
                        hasMore: result.books.hasMore
                    )

                    ForEach(result.books.items) { book in
                        NavigationLink {
                            BookDetailView(book: book.toBook())
                        } label: {
                            BookSearchResultRow(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Quotes Section
                if !result.quotes.items.isEmpty {
                    SearchCategoryHeader(
                        title: "search.quotes".localized,
                        icon: "quote.bubble.fill",
                        count: result.quotes.total,
                        hasMore: result.quotes.hasMore
                    )

                    ForEach(result.quotes.items) { quote in
                        QuoteSearchResultRow(quote: quote)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct SearchCategoryHeader: View {
    let title: String
    let icon: String
    let count: Int
    let hasMore: Bool

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
            Text("(\(count))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if hasMore {
                Text("search.viewMore".localized)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.top, 8)
    }
}

private struct AuthorSearchResultRow: View {
    let author: SearchAuthor

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .placeholder { _ in avatarPlaceholder }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                avatarPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(author.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    if let nameZh = author.nameZh {
                        Text("(\(nameZh))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    if let era = author.era {
                        Text(era)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(author.bookCount) " + "author.books".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }
}

private struct BookSearchResultRow: View {
    let book: SearchBook

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in coverPlaceholder }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 45, height: 68)
                    .cornerRadius(6)
            } else {
                coverPlaceholder
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 45, height: 68)
            .cornerRadius(6)
            .overlay(
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            )
    }
}

private struct QuoteSearchResultRow: View {
    let quote: SearchQuote

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quote text
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Text(quote.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

            // Attribution
            HStack {
                Text("— \(quote.authorName)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let source = quote.source {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Search Suggestions View

struct SearchSuggestionsView: View {
    let suggestions: [SearchSuggestion]
    let isLoading: Bool
    let onSelect: (SearchSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("search.loadingSuggestions".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ForEach(suggestions) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: suggestion.icon)
                                .foregroundColor(iconColor(for: suggestion.type))
                                .frame(width: 24)

                            Text(suggestion.text)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != suggestions.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func iconColor(for type: SearchSuggestion.SuggestionType) -> Color {
        switch type {
        case .author: return .purple
        case .book: return .blue
        case .popular: return .orange
        }
    }
}
