import SwiftUI
import Kingfisher

struct BookstoreSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchHistoryManager = SearchHistoryManager.shared
    @State private var searchText = ""
    @State private var unifiedSearchResult: UnifiedSearchResponse?
    @State private var isSearching = false
    @State private var suggestions: [SearchSuggestion] = []
    @State private var isLoadingSuggestions = false
    @State private var suggestionTask: Task<Void, Never>?
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar with back button
            searchBarWithBackButton

            Divider()

            // Content
            if !searchText.isEmpty && (isSearching || unifiedSearchResult != nil) {
                searchResultsContent
            } else if !searchText.isEmpty && !suggestions.isEmpty {
                suggestionsContent
            } else {
                searchAssistContent
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            isSearchFieldFocused = true
        }
    }

    // MARK: - Search Bar with Back Button

    private var searchBarWithBackButton: some View {
        HStack(spacing: 12) {
            // Back button
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("search.placeholder".localized, text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isSearchFieldFocused)
                    .onSubmit(performSearch)
                    .onChange(of: searchText) { _, newValue in
                        onSearchTextChange(newValue)
                    }

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        unifiedSearchResult = nil
                        suggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    // MARK: - Search Logic

    private func performSearch() {
        guard !searchText.isEmpty else {
            unifiedSearchResult = nil
            return
        }

        // Clear suggestions when performing actual search
        suggestions = []

        // Save to history
        searchHistoryManager.addSearch(searchText)

        isSearching = true
        Task {
            do {
                unifiedSearchResult = try await APIClient.shared.unifiedSearch(
                    query: searchText,
                    limit: 10
                )
            } catch {
                LoggingService.shared.debug(.books, "Search error: \(error)", component: "BookstoreSearchView")
                unifiedSearchResult = nil
            }
            isSearching = false
        }
    }

    private func onSearchTextChange(_ text: String) {
        suggestionTask?.cancel()

        guard text.count >= 2 else {
            suggestions = []
            return
        }

        suggestionTask = Task {
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                await fetchSuggestions(for: text)
            } catch {
                // Task cancelled
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
            suggestions = []
        }
    }

    // MARK: - Suggestions Content

    @ViewBuilder
    private var suggestionsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions) { suggestion in
                    Button {
                        searchText = suggestion.text
                        performSearch()
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
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if suggestion.id != suggestions.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
    }

    private func iconColor(for type: SearchSuggestion.SuggestionType) -> Color {
        switch type {
        case .author: return .purple
        case .book: return .blue
        case .popular: return .orange
        }
    }

    // MARK: - Search Assist Content

    @ViewBuilder
    private var searchAssistContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Search History
                if !searchHistoryManager.history.isEmpty {
                    searchHistorySection
                }
            }
            .padding(.bottom)
        }
    }

    private var searchHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("search.recentSearches".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button("common.clearAll".localized) {
                    searchHistoryManager.clearHistory()
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            ForEach(searchHistoryManager.history, id: \.self) { query in
                HStack {
                    Button {
                        searchText = query
                        performSearch()
                    } label: {
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

                    Button {
                        searchHistoryManager.removeSearch(query)
                    } label: {
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
    }

    // MARK: - Search Results Content

    @ViewBuilder
    private var searchResultsContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isSearching {
                    ProgressView("search.searching".localized)
                        .padding(40)
                } else if let result = unifiedSearchResult {
                    searchResultsView(result: result)
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

    @ViewBuilder
    private func searchResultsView(result: UnifiedSearchResponse) -> some View {
        if result.isEmpty {
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
                    searchSectionHeader(
                        title: "search.authors".localized,
                        icon: "person.fill",
                        count: result.authors.total,
                        hasMore: result.authors.hasMore
                    )

                    ForEach(result.authors.items) { author in
                        NavigationLink {
                            AuthorProfileView(authorId: author.id)
                        } label: {
                            authorRow(author: author)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Books Section
                if !result.books.items.isEmpty {
                    searchSectionHeader(
                        title: "search.books".localized,
                        icon: "book.fill",
                        count: result.books.total,
                        hasMore: result.books.hasMore
                    )

                    ForEach(result.books.items) { book in
                        NavigationLink {
                            BookDetailView(book: book.toBook())
                        } label: {
                            bookRow(book: book)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Quotes Section
                if !result.quotes.items.isEmpty {
                    searchSectionHeader(
                        title: "search.quotes".localized,
                        icon: "quote.bubble.fill",
                        count: result.quotes.total,
                        hasMore: result.quotes.hasMore
                    )

                    ForEach(result.quotes.items) { quote in
                        quoteRow(quote: quote)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func searchSectionHeader(title: String, icon: String, count: Int, hasMore: Bool) -> some View {
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

    private func authorRow(author: SearchAuthor) -> some View {
        HStack(spacing: 12) {
            if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .placeholder { _ in authorAvatarPlaceholder }
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                authorAvatarPlaceholder
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

    private var authorAvatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }

    private func bookRow(book: SearchBook) -> some View {
        HStack(spacing: 12) {
            if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in bookCoverPlaceholder }
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .frame(width: 45, height: 68)
                    .cornerRadius(6)
            } else {
                bookCoverPlaceholder
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

    private var bookCoverPlaceholder: some View {
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

    private func quoteRow(quote: SearchQuote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "quote.opening")
                    .font(.caption)
                    .foregroundColor(.accentColor)

                Text(quote.text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }

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
