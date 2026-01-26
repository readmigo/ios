import SwiftUI

struct SearchView: View {
    let bookId: String?
    let bookDetail: BookDetail?
    let onNavigate: (SearchResult) -> Void

    @StateObject private var searchManager = SearchManager.shared
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .currentBook
    @State private var searchType: SearchType = .keyword
    @State private var showFilters = false
    @State private var caseSensitive = false
    @State private var wholeWord = false
    @FocusState private var isSearchFocused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Search Type Picker
                searchTypePicker

                Divider()

                // Content
                if searchText.isEmpty {
                    recentSearchesView
                } else if searchManager.isSearching {
                    loadingView
                } else if searchManager.searchResults.isEmpty {
                    emptyResultsView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showFilters.toggle()
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFiltersView(
                    searchType: $searchType,
                    caseSensitive: $caseSensitive,
                    wholeWord: $wholeWord
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                isSearchFocused = true
            }
            .onChange(of: searchText) { _, newValue in
                performSearch(query: newValue)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search in book...", text: $searchText)
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchManager.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .padding()
    }

    // MARK: - Search Type Picker

    private var searchTypePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchType.allCases, id: \.self) { type in
                    SearchTypeChip(
                        type: type,
                        isSelected: searchType == type
                    ) {
                        searchType = type
                        if !searchText.isEmpty {
                            performSearch(query: searchText)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Recent Searches View

    private var recentSearchesView: some View {
        List {
            if !searchManager.recentSearches.isEmpty {
                Section("Recent Searches") {
                    ForEach(searchManager.recentSearches) { search in
                        Button {
                            searchText = search.query
                            performSearch(query: search.query)
                        } label: {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                Text(search.query)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                searchManager.removeRecentSearch(search)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }

                    Button("Clear Recent Searches") {
                        searchManager.clearRecentSearches()
                    }
                    .foregroundColor(.red)
                }
            }

            // Search Tips
            Section("Search Tips") {
                TipRow(icon: "magnifyingglass", title: "Keyword Search", description: "Find exact words or phrases")
                TipRow(icon: "brain.head.profile", title: "AI Semantic Search", description: "Find by meaning, not just words")
                TipRow(icon: "chevron.left.forwardslash.chevron.right", title: "Regex Search", description: "Use patterns for advanced search")
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty Results View

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Results")
                .font(.headline)

            Text("No matches found for \"\(searchText)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if searchType == .keyword {
                Button("Try AI Semantic Search") {
                    searchType = .semantic
                    performSearch(query: searchText)
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results View

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Results header
            HStack {
                Text("\(searchManager.totalMatches) results")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.2fs", searchManager.searchTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Results list
            List(searchManager.searchResults) { result in
                SearchResultRow(
                    result: result,
                    searchQuery: searchText
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onNavigate(result)
                    dismiss()
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Perform Search

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchManager.clearResults()
            return
        }

        let searchQuery = SearchQuery(
            query: query,
            bookId: bookId,
            chapterId: nil,
            searchType: searchType,
            caseSensitive: caseSensitive,
            wholeWord: wholeWord
        )

        Task {
            // Try local search first if book detail is available
            if let bookDetail = bookDetail, let bookId = bookId {
                let localResults = await searchManager.searchWithinBook(
                    query: query,
                    bookId: bookId,
                    bookDetail: bookDetail,
                    searchType: searchType
                )

                if !localResults.isEmpty {
                    searchManager.searchResults = localResults
                    searchManager.totalMatches = localResults.count
                    return
                }
            }

            // Fall back to API search
            await searchManager.search(query: searchQuery)
        }
    }
}

// MARK: - Search Type Chip

struct SearchTypeChip: View {
    let type: SearchType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.caption)
                Text(type.displayName)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: SearchResult
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Chapter info
            HStack {
                Text(result.chapterTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if let score = result.relevanceScore {
                    Text("\(Int(score * 100))% match")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Context with highlighted match
            highlightedText
                .font(.subheadline)
                .lineLimit(3)
        }
        .padding(.vertical, 8)
    }

    private var highlightedText: some View {
        let contextBefore = result.contextBefore.trimmingCharacters(in: .whitespaces)
        let matched = result.matchedText
        let contextAfter = result.contextAfter.trimmingCharacters(in: .whitespaces)

        return Text("...\(contextBefore)")
            .foregroundColor(.secondary)
        + Text(matched)
            .fontWeight(.bold)
            .foregroundColor(.orange)
        + Text("\(contextAfter)...")
            .foregroundColor(.secondary)
    }
}

// MARK: - Tip Row

struct TipRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Search Filters View

struct SearchFiltersView: View {
    @Binding var searchType: SearchType
    @Binding var caseSensitive: Bool
    @Binding var wholeWord: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Search Type") {
                    ForEach(SearchType.allCases, id: \.self) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                    .font(.subheadline)
                                Text(type.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if searchType == type {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            searchType = type
                        }
                    }
                }

                if searchType == .keyword {
                    Section("Options") {
                        Toggle("Case Sensitive", isOn: $caseSensitive)
                        Toggle("Whole Word", isOn: $wholeWord)
                    }
                }
            }
            .navigationTitle("Search Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
