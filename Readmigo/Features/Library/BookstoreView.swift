import SwiftUI
import Kingfisher
import Combine

struct BookstoreView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @StateObject private var bookListsManager = BookListsManager.shared
    @State private var showSearchView = false
    @State private var detailedLists: [BookList] = []
    @State private var isLoading = false

    // Individual books
    @State private var books: [BookWithScore] = []
    @State private var booksPage = 1
    @State private var hasMoreBooks = true
    @State private var isLoadingBooks = false

    // Banner carousel
    @State private var bannerIndex = 0
    @State private var bannerTimer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
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

                // Content
                bookListsContent
            }
            .navigationTitle("tab.discover".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showSearchView) {
                BookstoreSearchView()
            }
        }
        .task {
            if detailedLists.isEmpty && books.isEmpty {
                await loadAll()
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var bookListsContent: some View {
        if isLoading && detailedLists.isEmpty {
            VStack(spacing: 16) {
                ProgressView()
                Text("common.loading".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(40)
        } else if detailedLists.isEmpty && books.isEmpty {
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
                LazyVStack(spacing: 8) {
                    // Hero Banner Carousel
                    if bannerLists.count > 0 {
                        BookstoreHeroBanner(
                            lists: bannerLists,
                            currentIndex: $bannerIndex
                        )
                        .onAppear { startBannerTimer() }
                        .onDisappear { stopBannerTimer() }
                    }

                    // Category Menu
                    if !bookListsManager.categories.isEmpty {
                        BookstoreCategoryMenu(categories: bookListsManager.categories)
                    }

                    // Book Lists
                    ForEach(Array(detailedLists.enumerated()), id: \.element.id) { index, list in
                        BookListStyleDispatcher(list: list, styleIndex: index)
                    }

                    // Divider between lists and books
                    if !detailedLists.isEmpty && !books.isEmpty {
                        HStack {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                            Text("discover.allBooks".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .layoutPriority(1)
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }

                    // Individual Books
                    ForEach(books) { bookWithScore in
                        BookstoreBookRow(bookWithScore: bookWithScore)
                            .padding(.horizontal)
                            .onAppear {
                                if bookWithScore.id == books.last?.id, hasMoreBooks, !isLoadingBooks {
                                    Task {
                                        await loadMoreBooks()
                                    }
                                }
                            }
                    }

                    // Loading indicator for more books
                    if isLoadingBooks {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.bottom, 20)
            }
            .elegantRefreshable {
                await refreshAll()
            }
        }
    }

    // MARK: - Data Loading

    private func loadAll() async {
        isLoading = true

        // Load book lists, categories, and first page of books in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadAllBookLists() }
            group.addTask { await bookListsManager.fetchCategories() }
            group.addTask { await loadBooks(page: 1) }
        }

        isLoading = false
    }

    private func loadAllBookLists() async {
        await bookListsManager.fetchBookLists()

        var results: [BookList] = []
        await withTaskGroup(of: BookList?.self) { group in
            for list in bookListsManager.bookLists {
                group.addTask {
                    await bookListsManager.fetchBookList(id: list.id)
                }
            }
            for await result in group {
                if let list = result {
                    results.append(list)
                }
            }
        }

        detailedLists = results.sorted { ($0.sortOrder ?? 0) < ($1.sortOrder ?? 0) }
    }

    private func loadBooks(page: Int) async {
        isLoadingBooks = true
        do {
            let response = try await APIClient.shared.getBookstoreBooks(page: page)
            if page == 1 {
                books = response.books
            } else {
                let existingIds = Set(books.map(\.id))
                let newBooks = response.books.filter { !existingIds.contains($0.id) }
                books.append(contentsOf: newBooks)
            }
            hasMoreBooks = response.hasMore
            booksPage = page
        } catch {
            // Silently handle - books section just won't show
        }
        isLoadingBooks = false
    }

    private func loadMoreBooks() async {
        await loadBooks(page: booksPage + 1)
    }

    private func refreshAll() async {
        stopBannerTimer()
        detailedLists = []
        books = []
        booksPage = 1
        hasMoreBooks = true
        bannerIndex = 0
        await loadAll()
    }

    // MARK: - Banner

    private var bannerLists: [BookList] {
        Array(detailedLists.prefix(3))
    }

    private func startBannerTimer() {
        stopBannerTimer()
        guard bannerLists.count > 1 else { return }
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                bannerIndex = (bannerIndex + 1) % bannerLists.count
            }
        }
    }

    private func stopBannerTimer() {
        bannerTimer?.invalidate()
        bannerTimer = nil
    }
}

// MARK: - Hero Banner Carousel

private struct BookstoreHeroBanner: View {
    let lists: [BookList]
    @Binding var currentIndex: Int

    private func gradientColors(for type: BookListType) -> [Color] {
        switch type {
        case .ranking: return [Color.orange, Color.red]
        case .editorsPick: return [Color.blue, Color.purple]
        case .collection: return [Color.teal, Color.blue]
        case .university: return [Color.indigo, Color.blue]
        case .celebrity: return [Color.pink, Color.purple]
        case .annualBest: return [Color.yellow, Color.orange]
        case .aiRecommended: return [Color.purple, Color.blue]
        case .personalized: return [Color.pink, Color.red]
        case .aiFeatured: return [Color.cyan, Color.purple]
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            TabView(selection: $currentIndex) {
                ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                    NavigationLink {
                        BookListDetailView(bookListId: list.id)
                    } label: {
                        bannerCard(list: list)
                    }
                    .buttonStyle(.plain)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 150)

            // Page indicator
            if lists.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<lists.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .padding(.bottom, 8)
    }

    private func bannerCard(list: BookList) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            LinearGradient(
                colors: gradientColors(for: list.type),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative icon
            Image(systemName: list.type.icon)
                .font(.system(size: 70))
                .foregroundColor(.white.opacity(0.12))
                .offset(x: 240, y: -15)

            // Book covers preview
            if let books = list.books?.prefix(3), !books.isEmpty {
                HStack(spacing: -15) {
                    ForEach(Array(books.enumerated()), id: \.element.id) { i, book in
                        if let coverUrl = book.displayCoverUrl, let url = URL(string: coverUrl) {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(2/3, contentMode: .fill)
                                .frame(width: 50, height: 75)
                                .cornerRadius(4)
                                .shadow(color: .black.opacity(0.3), radius: 3)
                                .offset(y: CGFloat(i) * -4)
                        }
                    }
                }
                .offset(x: 250, y: -10)
            }

            // Text content
            VStack(alignment: .leading, spacing: 6) {
                // Type badge
                Text(list.type.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.25))
                    .cornerRadius(4)

                Text(list.localizedTitle)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if let subtitle = list.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption2)
                    Text("\(list.displayBookCount) books")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white.opacity(0.75))
            }
            .padding(16)
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Category Menu

private struct BookstoreCategoryMenu: View {
    let categories: [Category]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories.sorted(by: { ($0.bookCount) > ($1.bookCount) })) { category in
                    NavigationLink {
                        CategoryBooksListView(category: category)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: category.systemIconName)
                                .font(.system(size: 20))
                                .foregroundColor(.accentColor)
                                .frame(width: 44, height: 44)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Circle())

                            Text(category.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        .frame(width: 64)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Category Books List

struct CategoryBooksListView: View {
    let category: Category
    @StateObject private var manager = BookListsManager.shared
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMore = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if isLoading && books.isEmpty {
                    ProgressView()
                        .padding(40)
                } else if books.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: "No Books",
                        message: "No books in this category yet."
                    )
                } else {
                    ForEach(books) { book in
                        NavigationLink {
                            BookDetailView(book: book)
                        } label: {
                            CategoryBookRow(book: book)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if book.id == books.last?.id, hasMore, !isLoading {
                                currentPage += 1
                                Task { await loadBooks() }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView()
                            .padding()
                    }
                }
            }
        }
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if books.isEmpty {
                await loadBooks()
            }
        }
    }

    private func loadBooks() async {
        isLoading = true
        let newBooks = await manager.fetchBooks(inCategory: category.id, page: currentPage)
        books.append(contentsOf: newBooks)
        hasMore = newBooks.count == 20
        isLoading = false
    }
}

private struct CategoryBookRow: View {
    let book: Book

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Cover
            if let coverUrl = book.displayCoverUrl, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in coverPlaceholder }
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 70, height: 105)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            } else {
                coverPlaceholder
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // Description
                if let desc = book.description, !desc.isEmpty {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(2)
                        .padding(.top, 1)
                }

                Spacer(minLength: 4)

                // Compact metadata: word count + rating + difficulty
                HStack(spacing: 8) {
                    if let wc = book.wordCount {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 9))
                            Text(formatWordCount(wc))
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let rating = book.formattedRating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                            Text(rating)
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.secondary)
                    }

                    if let _ = book.difficultyScore {
                        HStack(spacing: 2) {
                            Circle()
                                .fill(difficultyColor)
                                .frame(width: 6, height: 6)
                            Text(book.difficultyLevel)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 44)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var difficultyColor: Color {
        guard let score = book.difficultyScore else { return .gray }
        switch score {
        case 0..<30: return .green
        case 30..<50: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 70, height: 105)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.gray)
            )
    }

    private func formatWordCount(_ wc: Int) -> String {
        if wc >= 1_000_000 { return String(format: "%.1fM", Double(wc) / 1_000_000) }
        if wc >= 1000 { return "\(wc / 1000)K" }
        return "\(wc)"
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
        HStack(alignment: .top, spacing: 12) {
            // Book info (tappable for navigation)
            HStack(alignment: .top, spacing: 12) {
                // Cover
                if let coverUrl = book.displayCoverUrl, let url = URL(string: coverUrl) {
                    KFImage(url)
                        .placeholder { _ in coverPlaceholder }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(2/3, contentMode: .fill)
                        .frame(width: 70, height: 105)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                } else {
                    coverPlaceholder
                }

                // Info
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundColor(.primary)

                    Text(book.localizedAuthor)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Description
                    if let desc = book.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(2)
                            .padding(.top, 1)
                    }

                    Spacer(minLength: 4)

                    // Compact metadata: word count + rating + difficulty
                    HStack(spacing: 8) {
                        if let wc = book.wordCount {
                            HStack(spacing: 2) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 9))
                                Text(formatWordCount(wc))
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }

                        if let rating = book.formattedRating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.orange)
                                Text(rating)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.secondary)
                        }

                        if let _ = book.difficultyScore {
                            HStack(spacing: 2) {
                                Circle()
                                    .fill(difficultyColor)
                                    .frame(width: 6, height: 6)
                                Text(book.difficultyLevel)
                                    .font(.caption2)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                navigateToDetail = true
            }

            // Favorite button
            VStack {
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .foregroundColor(isFavorited ? .red : .gray.opacity(0.5))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task {
                            let success = await favoritesManager.toggleFavorite(bookId: book.id)
                            if success {
                                isFavorited.toggle()
                            }
                        }
                    }
            }
        }
        .padding(.vertical, 2)
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

    private var difficultyColor: Color {
        guard let score = book.difficultyScore else { return .gray }
        switch score {
        case 0..<30: return .green
        case 30..<50: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .frame(width: 70, height: 105)
            .cornerRadius(8)
            .overlay(
                Image(systemName: "book.closed.fill")
                    .foregroundColor(.gray)
            )
    }

    private func formatWordCount(_ wc: Int) -> String {
        if wc >= 1_000_000 { return String(format: "%.1fM", Double(wc) / 1_000_000) }
        if wc >= 1000 { return "\(wc / 1000)K" }
        return "\(wc)"
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

            Text(list.localizedTitle)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)

            Text("discover.booksCount".localized(with: list.displayBookCount))
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
