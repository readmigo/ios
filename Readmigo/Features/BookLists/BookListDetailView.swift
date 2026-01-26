import SwiftUI
import Kingfisher

struct BookListDetailView: View {
    let bookListId: String

    @StateObject private var manager = BookListsManager.shared
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.dismiss) private var dismiss

    @State private var bookList: BookList?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let bookList = bookList {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            BookListHeader(bookList: bookList)

                            // Books Grid
                            if let books = bookList.books, !books.isEmpty {
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
                                    }
                                }
                                .padding(.horizontal)
                            } else {
                                EmptyStateView(
                                    icon: "books.vertical",
                                    title: "No Books",
                                    message: "This list doesn't have any books yet."
                                )
                            }

                            Spacer(minLength: 40)
                        }
                    }
                } else {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: "Not Found",
                        message: "This book list could not be found."
                    )
                }
            }
            .navigationTitle(bookList?.title ?? "Book List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadBookList()
            }
        }
    }

    private func loadBookList() async {
        isLoading = true
        bookList = await manager.fetchBookList(id: bookListId)
        isLoading = false
    }
}

// MARK: - Book List Header

struct BookListHeader: View {
    let bookList: BookList

    var body: some View {
        VStack(spacing: 16) {
            // Cover (with Kingfisher caching)
            if let coverUrl = bookList.coverUrl, !coverUrl.isEmpty, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.2))
                    }
                    .fade(duration: 0.25)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: bookList.type.icon)
                                .font(.largeTitle)
                                .foregroundColor(.white)
                            Text(bookList.type.displayName)
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
            }

            // Info
            VStack(spacing: 12) {
                Text(bookList.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                if let subtitle = bookList.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let description = bookList.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                // Stats
                HStack(spacing: 24) {
                    StatBadge(
                        icon: "book.closed.fill",
                        value: "\(bookList.bookCount)",
                        label: "Books"
                    )

                    StatBadge(
                        icon: bookList.type.icon,
                        value: bookList.type.displayName,
                        label: "Type"
                    )
                }
                .padding(.top, 8)
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(value)
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Book Grid Item

struct BookGridItem: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover (with Kingfisher caching)
            if let coverUrl = book.coverUrl, !coverUrl.isEmpty, let url = URL(string: coverUrl) {
                KFImage(url)
                    .placeholder { _ in ProgressView() }
                    .fade(duration: 0.25)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .cornerRadius(8)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(8)
                    .overlay {
                        Image(systemName: "book.closed")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}
