import SwiftUI

struct BookListsView: View {
    @StateObject private var manager = BookListsManager.shared
    @State private var selectedList: BookList?
    @State private var showingDetail = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // AI Personalized Section
                    if let aiList = manager.aiPersonalizedList {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: "For You",
                                icon: "sparkles",
                                iconColor: .purple
                            )

                            FeaturedBookListCard(bookList: aiList) {
                                selectedList = aiList
                                showingDetail = true
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Featured Lists
                    if !manager.featuredLists.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: "Featured",
                                icon: "star.fill",
                                iconColor: .yellow
                            )

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(manager.featuredLists) { list in
                                        BookListCard(bookList: list) {
                                            selectedList = list
                                            showingDetail = true
                                        }
                                        .frame(width: 280)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Lists by Type
                    ForEach(BookListType.allCases.filter { type in
                        manager.listsByType[type]?.isEmpty == false
                    }, id: \.self) { type in
                        if let lists = manager.listsByType[type], !lists.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeader(
                                    title: type.displayName,
                                    icon: type.icon,
                                    iconColor: .accentColor
                                )

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(lists) { list in
                                            CompactBookListCard(bookList: list) {
                                                selectedList = list
                                                showingDetail = true
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }

                    // Categories Section
                    if !manager.rootCategories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(
                                title: "Browse by Category",
                                icon: "folder.fill",
                                iconColor: .blue
                            )

                            NavigationLink {
                                CategoriesView()
                            } label: {
                                HStack {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible()),
                                        GridItem(.flexible())
                                    ], spacing: 12) {
                                        ForEach(manager.rootCategories.prefix(4)) { category in
                                            CategoryCard(category: category)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Book Lists")
            .elegantRefreshable {
                await manager.refreshAll()
            }
            .sheet(isPresented: $showingDetail) {
                if let list = selectedList {
                    BookListDetailView(bookListId: list.id)
                }
            }
            .overlay {
                if manager.isLoading && manager.bookLists.isEmpty {
                    ProgressView()
                }
            }
            .task {
                await manager.refreshAll()
            }
        }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal)
    }
}

// MARK: - Featured Book List Card

struct FeaturedBookListCard: View {
    let bookList: BookList
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 16) {
                // Cover
                if let coverUrl = bookList.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.2))
                    }
                    .frame(width: 100, height: 140)
                    .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 140)
                        .cornerRadius(8)
                        .overlay {
                            Image(systemName: "sparkles")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                }

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(bookList.localizedTitle)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let subtitle = bookList.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    if let description = bookList.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    HStack {
                        Image(systemName: "book.closed")
                        Text("\(bookList.displayBookCount) books")
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Book List Card

struct BookListCard: View {
    let bookList: BookList
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover
                if let coverUrl = bookList.coverUrl, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.2))
                    }
                    .frame(height: 150)
                    .cornerRadius(12)
                    .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                        .cornerRadius(12)
                        .overlay {
                            Image(systemName: bookList.type.icon)
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bookList.localizedTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack {
                        Image(systemName: "book.closed")
                        Text("\(bookList.displayBookCount) books")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 5)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Book List Card

struct CompactBookListCard: View {
    let bookList: BookList
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover
                ZStack {
                    if let coverUrl = bookList.coverUrl, let url = URL(string: coverUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                    } else {
                        Color.accentColor.opacity(0.2)
                    }

                    // Overlay with icon
                    Color.black.opacity(0.3)
                    Image(systemName: bookList.type.icon)
                        .foregroundColor(.white)
                        .font(.title3)
                }
                .frame(width: 120, height: 80)
                .cornerRadius(8)

                Text(bookList.localizedTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text("\(bookList.displayBookCount) books")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 120)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: Category

    var body: some View {
        VStack(spacing: 8) {
            if let iconUrl = category.iconUrl, let url = URL(string: iconUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFit()
                } placeholder: {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)
                }
                .frame(width: 40, height: 40)
            } else {
                Image(systemName: "folder.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }

            Text(category.name)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text("\(category.bookCount) books")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - All Cases Extension

extension BookListType: CaseIterable {
    static var allCases: [BookListType] {
        [.editorsPick, .annualBest, .university, .celebrity, .ranking, .collection, .aiRecommended, .personalized, .aiFeatured]
    }
}
