import SwiftUI

struct BooksPageView: View {
    let books: [AnnualReportBookDetail]

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.purple)

                    Text("Your Books")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("\(books.count) books this year")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 32)

                // Books grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(books) { book in
                        BookCardView(book: book)
                    }
                }
                .padding(.horizontal)

                Spacer(minLength: 50)
            }
        }
    }
}

// MARK: - Book Card View

struct BookCardView: View {
    let book: AnnualReportBookDetail

    var body: some View {
        VStack(spacing: 8) {
            // Cover
            ZStack(alignment: .bottomTrailing) {
                if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay {
                            Image(systemName: "book.closed")
                                .foregroundStyle(.secondary)
                        }
                }

                // Status badge
                if book.isFinished {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .background(Circle().fill(.white))
                        .padding(4)
                }
            }
            .aspectRatio(2/3, contentMode: .fit)
            .cornerRadius(8)
            .shadow(radius: 2)

            // Title
            Text(book.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Reading time
            Text("\(book.readingMinutes / 60)h")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
