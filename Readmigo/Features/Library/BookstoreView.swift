import SwiftUI
import Kingfisher
import Combine

struct BookstoreView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var showSearchView = false
    @State private var books: [BookWithScore] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var currentPage = 1
    @State private var loadMoreError = false
    private let pageSize = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar (tap to navigate to search page)
                Button {
                    showSearchView = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        Text("search.placeholder".localized)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Books list
                booksContent
            }
            .navigationTitle("tab.discover".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSearchView) {
                BookstoreSearchView()
            }
        }
        .task {
            if books.isEmpty {
                await loadBooks()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var booksContent: some View {
        if isLoading && books.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                Text("common.loading".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else if books.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                Text("discover.empty".localized)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(books.enumerated()), id: \.element.id) { index, bookWithScore in
                        BookstoreBookRow(bookWithScore: bookWithScore)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .onAppear {
                                // Auto-load more when reaching last item
                                if index == books.count - 1 && hasMore && !isLoadingMore && !loadMoreError {
                                    Task {
                                        await loadMoreBooks()
                                    }
                                }
                            }

                        if index < books.count - 1 {
                            Divider()
                                .padding(.horizontal)
                        }
                    }

                    // Load more indicator / retry button
                    if hasMore {
                        loadMoreView
                    }
                }
                .padding(.bottom)
            }
            .elegantRefreshable {
                await refreshBooks()
            }
        }
    }

    // MARK: - Load More View

    @ViewBuilder
    private var loadMoreView: some View {
        if loadMoreError {
            // Retry button on error
            Button {
                loadMoreError = false
                Task {
                    await loadMoreBooks()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("common.retry".localized)
                }
                .foregroundColor(.accentColor)
                .padding()
                .frame(maxWidth: .infinity)
            }
        } else if isLoadingMore {
            // Loading indicator
            ProgressView()
                .padding()
                .frame(maxWidth: .infinity)
        } else {
            // Spacer for auto-load trigger area
            Color.clear
                .frame(height: 1)
        }
    }

    // MARK: - Data Loading

    private func loadBooks() async {
        guard !isLoading else { return }
        isLoading = true

        do {
            let response = try await APIClient.shared.getBookstoreBooks(
                categoryId: nil,  // nil = all books
                page: 1,
                pageSize: pageSize
            )
            books = response.books
            currentPage = 1
            hasMore = response.hasMore
        } catch {
            LoggingService.shared.error(.books, "Failed to load books: \(error)")
        }

        isLoading = false
    }

    private func loadMoreBooks() async {
        guard !isLoadingMore && hasMore && !loadMoreError else { return }
        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await APIClient.shared.getBookstoreBooks(
                categoryId: nil,
                page: nextPage,
                pageSize: pageSize
            )
            books.append(contentsOf: response.books)
            currentPage = nextPage
            hasMore = response.hasMore
        } catch {
            LoggingService.shared.error(.books, "Failed to load more books: \(error)")
            loadMoreError = true
        }

        isLoadingMore = false
    }

    private func refreshBooks() async {
        currentPage = 1
        hasMore = true
        loadMoreError = false

        do {
            let response = try await APIClient.shared.getBookstoreBooks(
                categoryId: nil,
                page: 1,
                pageSize: pageSize
            )
            books = response.books
            hasMore = response.hasMore
        } catch {
            LoggingService.shared.error(.books, "Failed to refresh books: \(error)")
        }
    }
}

// MARK: - Bookstore Book Row

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
                    Task {
                        let success = await favoritesManager.toggleFavorite(bookId: book.id)
                        if success {
                            isFavorited.toggle()
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
