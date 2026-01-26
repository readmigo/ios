import SwiftUI

struct BookSearchView: View {
    let bookId: String
    let chapters: [Chapter]
    let onNavigate: (String, Int?) -> Void

    @StateObject private var searchService: BookSearchService
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    init(bookId: String, chapters: [Chapter], onNavigate: @escaping (String, Int?) -> Void) {
        self.bookId = bookId
        self.chapters = chapters
        self.onNavigate = onNavigate
        _searchService = StateObject(wrappedValue: BookSearchService(bookId: bookId))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Input
                searchInputSection

                Divider()

                // Results
                if searchService.isLoading && searchService.results.isEmpty {
                    loadingView
                } else if let error = searchService.error {
                    errorView(error)
                } else if searchService.results.isEmpty && !searchService.query.isEmpty {
                    noResultsView
                } else if searchService.results.isEmpty {
                    emptyStateView
                } else {
                    resultsList
                }
            }
            .navigationTitle("search.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Search Input

    private var searchInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("search.placeholder".localized, text: $searchService.query)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await searchService.search() }
                    }

                if !searchService.query.isEmpty {
                    Button {
                        searchService.clearResults()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)

            if searchService.totalMatches > 0 {
                HStack(spacing: 8) {
                    Text("search.resultsSummary".localized(
                        with: searchService.totalMatches,
                        searchService.matchingChapters
                    ))
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if searchService.isOfflineMode {
                        HStack(spacing: 4) {
                            Image(systemName: "icloud.slash")
                                .font(.system(size: 10))
                            Text("Offline")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            ForEach(searchService.results) { result in
                BookSearchResultSection(
                    result: result,
                    searchQuery: searchService.query,
                    onMatchTap: { match in
                        onNavigate(result.chapterId, match?.position)
                        dismiss()
                    }
                )
            }

            // Load More
            if searchService.currentPage < searchService.totalPages {
                Section {
                    Button {
                        Task { await searchService.loadMore() }
                    } label: {
                        HStack {
                            Spacer()
                            if searchService.isLoading {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text("search.loadMore".localized)
                            Spacer()
                        }
                    }
                    .disabled(searchService.isLoading)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("search.searching".localized)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("error.retry".localized) {
                Task { await searchService.search() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("search.noResults".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("search.tryDifferentQuery".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("search.emptyState".localized)
                .font(.headline)
                .foregroundColor(.secondary)
            Text("search.emptyStateHint".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }
}

// MARK: - Search Result Section

struct BookSearchResultSection: View {
    let result: SearchResultItem
    let searchQuery: String
    let onMatchTap: (SearchMatch?) -> Void

    @State private var isExpanded = false

    private var visibleMatches: [SearchMatch] {
        isExpanded ? result.matches : Array(result.matches.prefix(3))
    }

    private var hasMoreMatches: Bool {
        result.matches.count > 3
    }

    var body: some View {
        Section {
            // Chapter header
            Button {
                onMatchTap(nil)
            } label: {
                HStack {
                    Text("Chapter \(result.chapterOrder + 1): \(result.chapterTitle)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(result.matchCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }

            // Matches
            ForEach(visibleMatches) { match in
                Button {
                    onMatchTap(match)
                } label: {
                    SearchMatchRow(match: match, searchQuery: searchQuery)
                }
            }

            // Show more/less
            if hasMoreMatches {
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text(isExpanded
                            ? "search.showLess".localized
                            : "search.showMore".localized(with: result.matches.count - 3)
                        )
                        .font(.caption)
                        .foregroundColor(.blue)
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: - Search Match Row

struct SearchMatchRow: View {
    let match: SearchMatch
    let searchQuery: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Rectangle()
                .fill(Color.yellow.opacity(0.5))
                .frame(width: 3)
                .cornerRadius(1.5)

            VStack(alignment: .leading, spacing: 0) {
                highlightedText
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }

    private var highlightedText: some View {
        HStack(spacing: 0) {
            Text(match.beforeContext)
                .foregroundColor(.secondary)
            Text(match.matchedText)
                .foregroundColor(.primary)
                .fontWeight(.medium)
                .padding(.horizontal, 2)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(2)
            Text(match.afterContext)
                .foregroundColor(.secondary)
        }
        .lineLimit(3)
    }
}

