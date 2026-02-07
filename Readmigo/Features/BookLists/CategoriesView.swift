import SwiftUI
import Kingfisher

struct CategoriesView: View {
    @StateObject private var manager = BookListsManager.shared
    @State private var selectedCategory: Category?

    var body: some View {
        List {
            ForEach(manager.rootCategories) { category in
                CategoryRow(category: category)
            }
        }
        .navigationTitle("Categories")
        .elegantRefreshable {
            await manager.fetchCategories()
        }
        .overlay {
            if manager.isLoading && manager.categories.isEmpty {
                ProgressView()
            }
        }
        .task {
            if manager.categories.isEmpty {
                await manager.fetchCategories()
            }
        }
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: Category
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Main Category
            NavigationLink {
                CategoryBooksView(category: category)
            } label: {
                HStack(spacing: 12) {
                    // Icon - use system icon based on category identifier
                    Image(systemName: category.systemIconName)
                        .font(.title3)
                        .foregroundColor(.accentColor)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.displayName)
                            .font(.body)
                            .fontWeight(.medium)

                        if let description = category.description {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Text("\(category.bookCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(8)
                }
            }

            // Subcategories
            if let children = category.children, !children.isEmpty {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Text("\(children.count) subcategories")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.leading, 44)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(children) { child in
                            NavigationLink {
                                CategoryBooksView(category: child)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .foregroundColor(.secondary)
                                        .frame(width: 24)

                                    Text(child.displayName)
                                        .font(.subheadline)

                                    Spacer()

                                    Text("\(child.bookCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.leading, 44)
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Category Books View

struct CategoryBooksView: View {
    let category: Category
    @StateObject private var manager = BookListsManager.shared
    @State private var books: [Book] = []
    @State private var isLoading = true
    @State private var currentPage = 1
    @State private var hasMore = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Category Header
                VStack(spacing: 12) {
                    if let coverUrl = category.coverUrl, let url = URL(string: coverUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.2))
                        }
                        .frame(height: 150)
                        .clipped()
                    }

                    if let description = category.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text("\(category.bookCount) books")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Subcategories
                if let children = category.children, !children.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subcategories")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(children) { child in
                                    NavigationLink {
                                        CategoryBooksView(category: child)
                                    } label: {
                                        SubcategoryChip(category: child)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Books
                if isLoading && books.isEmpty {
                    ProgressView()
                        .padding()
                } else if books.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical",
                        title: "No Books",
                        message: "No books in this category yet."
                    )
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(books) { book in
                            NavigationLink {
                                BookDetailView(book: book)
                            } label: {
                                BookGridItem(book: book)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                loadMoreIfNeeded(book: book)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                if isLoading && !books.isEmpty {
                    ProgressView()
                        .padding()
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle(category.displayName)
        .task {
            await loadBooks()
        }
    }

    private func loadBooks() async {
        isLoading = true
        let newBooks = await manager.fetchBooks(inCategory: category.id, page: currentPage)
        books.append(contentsOf: newBooks)
        hasMore = newBooks.count == 20 // Assuming 20 per page
        isLoading = false
    }

    private func loadMoreIfNeeded(book: Book) {
        guard let lastBook = books.last,
              book.id == lastBook.id,
              hasMore,
              !isLoading else {
            return
        }

        currentPage += 1
        Task {
            await loadBooks()
        }
    }
}

// MARK: - Subcategory Chip

struct SubcategoryChip: View {
    let category: Category

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: category.systemIconName)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20)

            Text(category.displayName)
                .font(.subheadline)

            Text("\(category.bookCount)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 3)
    }
}

// MARK: - Book Grid Item (for Book type)

struct BookGridItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let coverUrl = book.coverThumbUrl ?? book.coverUrl, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in coverPlaceholder }
                    .fade(duration: 0.25)
                    .resizable()
                    .aspectRatio(2/3, contentMode: .fill)
                    .cornerRadius(8)
                    .clipped()
            } else {
                coverPlaceholder
            }

            Text(book.localizedTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(book.localizedAuthor)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.15))
            .aspectRatio(2/3, contentMode: .fill)
            .cornerRadius(8)
            .overlay {
                Image(systemName: "book.closed")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.5))
            }
    }
}
