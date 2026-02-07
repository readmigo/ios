import SwiftUI
import Kingfisher

struct BookListDetailView: View {
    let bookListId: String

    @StateObject private var manager = BookListsManager.shared
    @EnvironmentObject var libraryManager: LibraryManager

    @State private var bookList: BookList?
    @State private var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let bookList = bookList {
                ScrollView {
                    VStack(spacing: 0) {
                        // Banner
                        BookListBanner(bookList: bookList)

                        // Books Grid
                        if let books = bookList.books, !books.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 16) {
                                ForEach(books) { book in
                                    NavigationLink {
                                        BookDetailView(book: book.toBook())
                                    } label: {
                                        BookListBookGridItem(book: book)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
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
        .navigationTitle(bookList?.localizedTitle ?? "Book List")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBookList()
        }
    }

    private func loadBookList() async {
        isLoading = true
        bookList = await manager.fetchBookList(id: bookListId)
        isLoading = false
    }
}

// MARK: - Book List Banner

private struct BookListBanner: View {
    let bookList: BookList

    private var gradientColors: [Color] {
        switch bookList.type {
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
        ZStack(alignment: .bottomLeading) {
            // Background gradient
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 180)

            // Decorative icon
            Image(systemName: bookList.type.icon)
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.15))
                .offset(x: 220, y: -20)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Type badge
                Text(bookList.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(4)

                Text(bookList.localizedTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                if let subtitle = bookList.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }

                HStack(spacing: 4) {
                    Image(systemName: "book.closed.fill")
                        .font(.caption2)
                    Text("\(bookList.displayBookCount) books")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
        }
        .clipped()
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

struct BookListBookGridItem: View {
    let book: BookListBook

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover with 2:3 aspect ratio
            if let coverUrl = book.displayCoverUrl, let url = URL(string: coverUrl) {
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

            // Title - 1 line
            Text(book.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            // Author - 1 line
            Text(book.authorName)
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
