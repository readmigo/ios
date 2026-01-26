import SwiftUI
import Kingfisher

struct BrowseBooksView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var selectedGenre: String?
    @State private var selectedDifficulty: DifficultyLevel?
    @State private var selectedCascadeCategory: CascadeCategory?
    @State private var sortOption: SortOption = .newest

    let genres = ["Fiction", "Classic", "Romance", "Mystery", "Science Fiction", "Fantasy", "Adventure", "Drama"]

    enum SortOption: String, CaseIterable {
        case newest = "Newest"
        case popular = "Popular"
        case difficulty = "Difficulty"
        case alphabetical = "A-Z"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Filter Summary Bar
                FilterSummaryBar(
                    genre: selectedGenre,
                    difficulty: selectedDifficulty,
                    cascadeCategory: selectedCascadeCategory,
                    onClear: clearFilters
                )

                // Cascade Category Selector
                CategoryCascadeSelector { category in
                    selectedCascadeCategory = category
                }

                // Genre Filter
                GenreFilterSection(
                    genres: genres,
                    selectedGenre: $selectedGenre
                )

                // Difficulty Filter
                DifficultyFilterSection(selectedDifficulty: $selectedDifficulty)

                // Sort Options
                SortOptionsBar(sortOption: $sortOption)

                // Results Count
                HStack {
                    Text("\(filteredBooks.count) books found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)

                // Books Grid
                BrowseBooksGrid(
                    books: sortedBooks,
                    hasMore: libraryManager.hasMoreBooks && !hasActiveFilters,
                    isLoading: libraryManager.isLoading,
                    onLoadMore: {
                        Task {
                            await libraryManager.loadMoreBooks()
                        }
                    }
                )
            }
            .padding(.bottom)
        }
        .navigationTitle("Browse Books")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if libraryManager.allBooks.isEmpty {
                await libraryManager.fetchAllBooks()
            }
        }
    }

    private var hasActiveFilters: Bool {
        selectedGenre != nil || selectedDifficulty != nil || selectedCascadeCategory != nil
    }

    private var filteredBooks: [Book] {
        var books = libraryManager.allBooks

        if let genre = selectedGenre {
            books = books.filter { ($0.genres ?? []).contains(genre) }
        }

        if let difficulty = selectedDifficulty {
            books = books.filter { book in
                guard let score = book.difficultyScore else { return false }
                return difficulty.range.contains(score)
            }
        }

        if let category = selectedCascadeCategory {
            books = books.filter { book in
                (book.subjects ?? []).contains(category.nameEn) || (book.genres ?? []).contains(category.nameEn)
            }
        }

        return books
    }

    private var sortedBooks: [Book] {
        switch sortOption {
        case .newest:
            return filteredBooks.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .popular:
            return filteredBooks
        case .difficulty:
            return filteredBooks.sorted { ($0.difficultyScore ?? 0) < ($1.difficultyScore ?? 0) }
        case .alphabetical:
            return filteredBooks.sorted { $0.title < $1.title }
        }
    }

    private func clearFilters() {
        selectedGenre = nil
        selectedDifficulty = nil
        selectedCascadeCategory = nil
    }
}

// MARK: - Filter Summary Bar

private struct FilterSummaryBar: View {
    let genre: String?
    let difficulty: DifficultyLevel?
    let cascadeCategory: CascadeCategory?
    let onClear: () -> Void

    var hasFilters: Bool {
        genre != nil || difficulty != nil || cascadeCategory != nil
    }

    var body: some View {
        if hasFilters {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let category = cascadeCategory {
                        ActiveFilterChip(label: category.nameEn, onRemove: {})
                    }
                    if let genre = genre {
                        ActiveFilterChip(label: genre, onRemove: {})
                    }
                    if let difficulty = difficulty {
                        ActiveFilterChip(label: difficulty.rawValue, color: difficulty.color, onRemove: {})
                    }

                    Button("Clear All") {
                        onClear()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(16)
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct ActiveFilterChip: View {
    let label: String
    var color: Color = .blue
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)

            Image(systemName: "xmark")
                .font(.caption2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color)
        .cornerRadius(16)
        .onTapGesture(perform: onRemove)
    }
}

// MARK: - Sort Options Bar

private struct SortOptionsBar: View {
    @Binding var sortOption: BrowseBooksView.SortOption

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort by")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BrowseBooksView.SortOption.allCases, id: \.self) { option in
                        SortChip(
                            title: option.rawValue,
                            isSelected: sortOption == option
                        ) {
                            sortOption = option
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct SortChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .cornerRadius(16)
        }
    }
}

// MARK: - Books Grid

private struct BrowseBooksGrid: View {
    let books: [Book]
    let hasMore: Bool
    let isLoading: Bool
    let onLoadMore: () -> Void

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(books) { book in
                BrowseBookGridItem(book: book)
            }
        }
        .padding(.horizontal)

        if hasMore && !isLoading {
            Button {
                onLoadMore()
            } label: {
                HStack {
                    Text("Load More")
                    Image(systemName: "arrow.down.circle")
                }
                .foregroundColor(.accentColor)
                .padding()
            }
        }

        if isLoading {
            ProgressView()
                .padding()
        }
    }
}

// MARK: - Browse Book Grid Item (with favorite button)

private struct BrowseBookGridItem: View {
    let book: Book
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var isFavorited: Bool = false
    @State private var navigateToDetail: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover with favorite button overlay
            ZStack(alignment: .topTrailing) {
                // Cover image (tappable for navigation)
                ZStack {
                    if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                        KFImage(url)
                            .placeholder { _ in coverPlaceholder }
                            .fade(duration: 0.25)
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    } else {
                        coverPlaceholder
                    }

                    // Difficulty Badge (bottom-right)
                    if let score = book.difficultyScore {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                BrowseDifficultyBadge(score: score)
                                    .padding(6)
                            }
                        }
                    }
                }
                .frame(height: 150)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                .contentShape(Rectangle())
                .onTapGesture {
                    navigateToDetail = true
                }

                // Favorite button (top-right)
                Image(systemName: isFavorited ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundColor(isFavorited ? .red : .white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.6))
                    .clipShape(Circle())
                    .contentShape(Circle())
                    .onTapGesture {
                        LoggingService.shared.debug(.books, "❤️ [BrowseBookGridItem] Heart tapped! bookId: \(book.id)", component: "BrowseBooksView")
                        LoggingService.shared.debug(.books, "❤️ [BrowseBookGridItem] Current isFavorited: \(isFavorited)", component: "BrowseBooksView")
                        Task {
                            LoggingService.shared.debug(.books, "❤️ [BrowseBookGridItem] Calling toggleFavorite...", component: "BrowseBooksView")
                            let success = await favoritesManager.toggleFavorite(bookId: book.id)
                            LoggingService.shared.debug(.books, "❤️ [BrowseBookGridItem] toggleFavorite returned: \(success)", component: "BrowseBooksView")
                            if success {
                                isFavorited.toggle()
                                LoggingService.shared.debug(.books, "❤️ [BrowseBookGridItem] isFavorited toggled to: \(isFavorited)", component: "BrowseBooksView")
                            }
                        }
                    }
                    .padding(6)
            }

            // Title
            Text(book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(.primary)

            // Author
            Text(book.localizedAuthor)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
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
            .overlay(
                Image(systemName: "book.closed.fill")
                    .font(.title)
                    .foregroundColor(.gray)
            )
    }
}

private struct BrowseDifficultyBadge: View {
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
        Text(level.rawValue.prefix(1))
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(level.color)
            .cornerRadius(4)
    }
}
