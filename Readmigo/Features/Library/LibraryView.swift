import SwiftUI
import Kingfisher

struct LibraryView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var browsingHistoryManager: BrowsingHistoryManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var readingProgressStore: ReadingProgressStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if authManager.isGuestMode && !authManager.isAuthenticated {
                        // Guest mode: show browsing history only
                        GuestLibraryContentView(
                            browsingHistory: browsingHistoryManager.localHistory,
                            onClearHistory: {
                                Task { await browsingHistoryManager.clearHistory() }
                            }
                        )
                    } else {
                        // Authenticated user view

                        // 1. Currently Reading Section (merged local + cloud)
                        if let currentlyReading = readingProgressStore.mergedCurrentlyReading {
                            CurrentlyReadingLocalSection(currentlyReading: currentlyReading)
                        }

                        // 2. Recently Browsed Section (horizontal scroll, merged local + cloud)
                        if !browsingHistoryManager.mergedHistory.isEmpty {
                            RecentlyBrowsedMergedSection()
                        }

                        // 3. Favorite Books Section (3-column grid)
                        if !favoritesManager.isEmpty {
                            FavoriteBooksSection()
                        }

                        // Empty state when everything is empty
                        if readingProgressStore.mergedCurrentlyReading == nil &&
                           browsingHistoryManager.mergedHistory.isEmpty &&
                           favoritesManager.isEmpty {
                            EmptyLibraryStateView()
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("nav.library".localized)
            .navigationBarTitleDisplayMode(.inline)
            // Pull-to-refresh disabled - data refreshes automatically on tab switch
        }
        .task {
            await loadInitialData()
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        if authManager.isAuthenticated {
            // Fetch cloud data (browsing history + favorites + reading progress)
            await browsingHistoryManager.fetchFromServer()
            await favoritesManager.fetchFavorites()
            await readingProgressStore.fetchFromServer()
        }
    }
}

// MARK: - Currently Reading Local Section (from Core Data)

struct CurrentlyReadingLocalSection: View {
    let currentlyReading: CurrentlyReading
    @State private var showingReader = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("library.section.continueReading".localized)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            // Entire card is clickable - opens reader directly
            Button {
                showingReader = true
            } label: {
                CurrentlyReadingLocalCard(currentlyReading: currentlyReading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .fullScreenCover(isPresented: $showingReader) {
            EnhancedReaderView(viewModel: ReaderViewModel(book: currentlyReading.book))
                .environmentObject(ThemeManager.shared)
        }
    }
}

// MARK: - Currently Reading Local Card (New Design)

struct CurrentlyReadingLocalCard: View {
    let currentlyReading: CurrentlyReading

    private var progress: Double {
        guard let chapterCount = currentlyReading.book.chapterCount, chapterCount > 0 else {
            return 0
        }
        let chapterProgress = Double(currentlyReading.currentChapter) / Double(chapterCount)
        let inChapterProgress = currentlyReading.scrollPosition / Double(chapterCount)
        return min(1.0, chapterProgress + inChapterProgress)
    }

    private var estimatedTimeLeft: String {
        guard let wordCount = currentlyReading.book.wordCount, wordCount > 0 else {
            return ""
        }
        let wordsRead = Int(Double(wordCount) * progress)
        let wordsLeft = wordCount - wordsRead
        let readingSpeedWPM = 200
        let minutesLeft = wordsLeft / readingSpeedWPM
        if minutesLeft < 60 {
            return "\(minutesLeft)m left"
        } else {
            let hours = minutesLeft / 60
            return "\(hours)h left"
        }
    }

    private var chapterProgress: String {
        guard let chapterCount = currentlyReading.book.chapterCount, chapterCount > 0 else {
            return ""
        }
        return "Chapter \(currentlyReading.currentChapter + 1) of \(chapterCount)"
    }

    private var lastReadText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last read: \(formatter.localizedString(for: currentlyReading.lastReadAt, relativeTo: Date()))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Book Cover
                Group {
                    if let urlString = currentlyReading.book.displayCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                        KFImage(url)
                            .loadDiskFileSynchronously()
                            .placeholder { _ in ProgressView() }
                            .fade(duration: 0.25)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "book.fill")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 80, height: 120)
                .cornerRadius(8)
                .clipped()

                // Book Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentlyReading.book.localizedTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .foregroundColor(.primary)

                            Text(currentlyReading.book.localizedAuthor)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !estimatedTimeLeft.isEmpty {
                            Text(estimatedTimeLeft)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Progress section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(chapterProgress.isEmpty ? "\(Int(progress * 100))% complete" : chapterProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(progress * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.brandLavender)
                        }

                        ProgressView(value: progress)
                            .tint(.brandLavender)
                    }
                }
            }
            .padding(16)

            // Bottom bar
            Divider()

            HStack {
                Text(lastReadText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("library.continue".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLavender)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Currently Reading Section (Legacy - for UserBook)

struct CurrentlyReadingSection: View {
    let userBook: UserBook

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("library.section.continueReading".localized)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)

            NavigationLink {
                BookDetailView(book: userBook.book)
            } label: {
                CurrentlyReadingCard(userBook: userBook)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
    }
}

// MARK: - Currently Reading Card (New Design)

struct CurrentlyReadingCard: View {
    let userBook: UserBook

    private var estimatedTimeLeft: String {
        guard let wordCount = userBook.book.wordCount, wordCount > 0 else {
            return ""
        }
        let wordsRead = Int(Double(wordCount) * userBook.safeProgress)
        let wordsLeft = wordCount - wordsRead
        let readingSpeedWPM = 200 // Average reading speed
        let minutesLeft = wordsLeft / readingSpeedWPM
        if minutesLeft < 60 {
            return "\(minutesLeft)m left"
        } else {
            let hours = minutesLeft / 60
            return "\(hours)h left"
        }
    }

    private var pageProgress: String {
        guard let chapterCount = userBook.book.chapterCount, chapterCount > 0 else {
            return ""
        }
        let currentPage = Int(Double(chapterCount) * userBook.safeProgress)
        return "Page \(max(1, currentPage)) of \(chapterCount)"
    }

    private var lastReadText: String {
        guard let lastRead = userBook.lastReadAt else {
            return ""
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last read: \(formatter.localizedString(for: lastRead, relativeTo: Date()))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main content
            HStack(spacing: 16) {
                // Book Cover
                Group {
                    if let urlString = userBook.book.displayCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                        KFImage(url)
                            .loadDiskFileSynchronously()
                            .placeholder { _ in ProgressView() }
                            .fade(duration: 0.25)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .overlay(
                                Image(systemName: "book.fill")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 80, height: 120)
                .cornerRadius(8)
                .clipped()

                // Book Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userBook.book.localizedTitle)
                                .font(.headline)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .foregroundColor(.primary)

                            Text(userBook.book.localizedAuthor)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if !estimatedTimeLeft.isEmpty {
                            Text(estimatedTimeLeft)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    // Progress section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(pageProgress.isEmpty ? "\(Int(userBook.safeProgress * 100))% complete" : pageProgress)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(Int(userBook.safeProgress * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.brandLavender)
                        }

                        ProgressView(value: userBook.safeProgress)
                            .tint(.brandLavender)
                    }
                }
            }
            .padding(16)

            // Bottom bar
            Divider()

            HStack {
                if !lastReadText.isEmpty {
                    Text(lastReadText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("library.continue".localized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandLavender)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Recently Browsed Merged Section (local + cloud)

struct RecentlyBrowsedMergedSection: View {
    @EnvironmentObject var browsingHistoryManager: BrowsingHistoryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("library.recentlyBrowsed".localized)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink {
                    RecentlyBrowsedMergedFullView()
                } label: {
                    Text("common.seeAll".localized)
                        .font(.subheadline)
                        .foregroundColor(.brandLavender)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(browsingHistoryManager.mergedHistory.prefix(10)) { item in
                        NavigationLink {
                            BookDetailViewById(bookId: item.id)
                        } label: {
                            RecentlyBrowsedMergedCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecentlyBrowsedMergedCard: View {
    let item: BrowsingHistoryDisplayItem
    @State private var useFullCover = false

    /// Use thumb URL first, fallback to full cover URL if thumb fails
    private var effectiveCoverUrl: String? {
        if useFullCover {
            return item.coverUrl
        }
        return item.coverThumbUrl ?? item.coverUrl
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover - try thumbUrl first, fallback to full coverUrl on failure
            Group {
                if let urlString = effectiveCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    KFImage(url)
                        .loadDiskFileSynchronously()
                        .placeholder { _ in ProgressView() }
                        .onFailure { _ in
                            // If thumb failed and we have a different full cover URL, try it
                            if !useFullCover && item.coverThumbUrl != nil && item.coverUrl != nil && item.coverThumbUrl != item.coverUrl {
                                useFullCover = true
                            }
                        }
                        .retry(maxCount: 2, interval: .seconds(1))
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback: show book icon
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 80, height: 120)
            .cornerRadius(8)
            .clipped()
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title
            Text(item.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 80, height: 34, alignment: .topLeading)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Recently Browsed Merged Full View

struct RecentlyBrowsedMergedFullView: View {
    @EnvironmentObject var browsingHistoryManager: BrowsingHistoryManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(browsingHistoryManager.mergedHistory) { item in
                    NavigationLink {
                        BookDetailViewById(bookId: item.id)
                    } label: {
                        RecentlyBrowsedGridCardV2(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
        .navigationTitle("library.recentlyBrowsed".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Recently Browsed Horizontal Section (Legacy - cloud only)

struct RecentlyBrowsedHorizontalSection: View {
    @EnvironmentObject var browsingHistoryManager: BrowsingHistoryManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("library.recentlyBrowsed".localized)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                NavigationLink {
                    RecentlyBrowsedFullView()
                } label: {
                    Text("common.seeAll".localized)
                        .font(.subheadline)
                        .foregroundColor(.brandLavender)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(browsingHistoryManager.cloudHistory.prefix(10)) { item in
                        NavigationLink {
                            BookDetailViewById(bookId: item.bookId)
                        } label: {
                            RecentlyBrowsedHorizontalCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecentlyBrowsedHorizontalCard: View {
    let item: BrowsingHistoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover
            Group {
                if let urlString = item.book.displayCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    KFImage(url)
                        .loadDiskFileSynchronously()
                        .placeholder { _ in ProgressView() }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 80, height: 120)
            .cornerRadius(8)
            .clipped()
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title
            Text(item.book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 80, height: 34, alignment: .topLeading)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Recently Browsed Full View

struct RecentlyBrowsedFullView: View {
    @EnvironmentObject var browsingHistoryManager: BrowsingHistoryManager
    @State private var editMode: EditMode = .inactive
    @State private var selectedBooks: Set<String> = []
    @State private var showDeleteConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if editMode == .active {
                    // Edit mode toolbar
                    HStack {
                        if !selectedBooks.isEmpty {
                            Button {
                                showDeleteConfirmation = true
                            } label: {
                                Text("library.deleteSelected".localized(with: selectedBooks.count))
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(browsingHistoryManager.cloudHistory) { item in
                        NavigationLink {
                            BookDetailViewById(bookId: item.bookId)
                        } label: {
                            RecentlyBrowsedGridCardV2(item: BrowsingHistoryDisplayItem(
                                id: item.bookId,
                                title: item.book.title,
                                author: item.book.author,
                                coverUrl: item.book.coverUrl,
                                coverThumbUrl: item.book.coverThumbUrl
                            ))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("library.recentlyBrowsed".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        editMode = editMode == .active ? .inactive : .active
                        if editMode == .inactive {
                            selectedBooks.removeAll()
                        }
                    }
                } label: {
                    Text(editMode == .active ? "common.done".localized : "common.edit".localized)
                }
            }
        }
        .confirmationDialog(
            "library.deleteSelected.title".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("library.deleteSelected.confirm".localized(with: selectedBooks.count), role: .destructive) {
                Task {
                    await browsingHistoryManager.batchDelete(ids: selectedBooks)
                    selectedBooks.removeAll()
                    editMode = .inactive
                }
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
    }
}

// MARK: - Favorite Books Section

struct FavoriteBooksSection: View {
    @EnvironmentObject var favoritesManager: FavoritesManager

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("library.favorites".localized)
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if favoritesManager.favorites.count > 9 {
                    NavigationLink {
                        FavoriteBooksFullView()
                    } label: {
                        Text("common.seeAll".localized)
                            .font(.subheadline)
                            .foregroundColor(.brandLavender)
                    }
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(favoritesManager.favorites.prefix(9)) { favorite in
                    NavigationLink {
                        BookDetailViewById(bookId: favorite.bookId)
                    } label: {
                        FavoriteBookCard(favorite: favorite)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }
}

struct FavoriteBookCard: View {
    let favorite: FavoriteBook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            Color.clear
                .aspectRatio(2/3, contentMode: .fit)
                .overlay(
                    Group {
                        if let urlString = favorite.book.displayCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                            KFImage(url)
                                .loadDiskFileSynchronously()
                                .placeholder { _ in ProgressView() }
                                .fade(duration: 0.25)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "book.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                )
                .clipped()
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title
            Text(favorite.book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(height: 34, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Favorite Books Full View

struct FavoriteBooksFullView: View {
    @EnvironmentObject var favoritesManager: FavoritesManager
    @State private var selectedBooks: Set<String> = []
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isEditing && !selectedBooks.isEmpty {
                    HStack {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("library.deleteSelected".localized(with: selectedBooks.count))
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(favoritesManager.favorites) { favorite in
                        NavigationLink {
                            BookDetailViewById(bookId: favorite.bookId)
                        } label: {
                            FavoriteBookCard(favorite: favorite)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("library.favorites".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation {
                        isEditing.toggle()
                        if !isEditing {
                            selectedBooks.removeAll()
                        }
                    }
                } label: {
                    Text(isEditing ? "common.done".localized : "common.edit".localized)
                }
            }
        }
        .confirmationDialog(
            "library.deleteSelected.title".localized,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("library.deleteSelected.confirm".localized(with: selectedBooks.count), role: .destructive) {
                Task {
                    _ = await favoritesManager.batchDelete(bookIds: Array(selectedBooks))
                    selectedBooks.removeAll()
                    isEditing = false
                }
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
    }
}

// MARK: - Empty State

struct EmptyLibraryStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))

            Text("library.empty.title".localized)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("library.empty.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink(destination: DiscoverView()) {
                Text("library.empty.discoverBooks".localized)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 400)
        .padding(24)
    }
}

// MARK: - Guest Library Content View

struct GuestLibraryContentView: View {
    let browsingHistory: [BrowsingHistoryManager.BrowsedBook]
    let onClearHistory: () -> Void
    @EnvironmentObject var authManager: AuthManager
    @State private var showClearConfirmation = false

    var body: some View {
        if browsingHistory.isEmpty {
            GuestEmptyLibraryView()
        } else {
            // Recently Browsed Section (horizontal scroll for guest)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("library.recentlyBrowsed".localized)
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    Button {
                        showClearConfirmation = true
                    } label: {
                        Text("common.clear".localized)
                            .font(.subheadline)
                            .foregroundColor(.brandLavender)
                    }
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(browsingHistory) { book in
                            NavigationLink {
                                BookDetailViewById(bookId: book.id)
                            } label: {
                                GuestBrowsedBookCard(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                // Login prompt
                GuestLoginPromptCard()
                    .padding(.top, 16)
            }
            .alert(
                "library.clearHistory.title".localized,
                isPresented: $showClearConfirmation
            ) {
                Button("library.clearHistory.confirm".localized, role: .destructive) {
                    onClearHistory()
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("library.clearHistory.message".localized)
            }
        }
    }
}

struct GuestBrowsedBookCard: View {
    let book: BrowsingHistoryManager.BrowsedBook
    @State private var useFullCover = false

    /// Use thumb URL first, fallback to full cover URL if thumb fails
    private var effectiveCoverUrl: String? {
        if useFullCover {
            return book.coverUrl
        }
        return book.coverThumbUrl ?? book.coverUrl
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Cover - try thumbUrl first, fallback to full coverUrl on failure
            Group {
                if let urlString = effectiveCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    KFImage(url)
                        .loadDiskFileSynchronously()
                        .placeholder { _ in ProgressView() }
                        .onFailure { _ in
                            // If thumb failed and we have a different full cover URL, try it
                            if !useFullCover && book.coverThumbUrl != nil && book.coverUrl != nil && book.coverThumbUrl != book.coverUrl {
                                useFullCover = true
                            }
                        }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.title3)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 80, height: 120)
            .cornerRadius(8)
            .clipped()
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title
            Text(book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 80, height: 34, alignment: .topLeading)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Guest Empty Library View

struct GuestEmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.6))

            Text("library.guest.empty.title".localized)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("library.guest.empty.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink(destination: DiscoverView()) {
                Text("library.empty.discoverBooks".localized)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(10)
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

// MARK: - Guest Login Prompt Card

struct GuestLoginPromptCard: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Text("library.guest.benefits.title".localized)
                    .font(.headline)
                    .foregroundColor(.textPrimary)

                BenefitRow(icon: "cloud", text: "library.guest.benefit1".localized)
                BenefitRow(icon: "arrow.triangle.2.circlepath", text: "library.guest.benefit2".localized)
            }

            Button {
                authManager.isGuestMode = false
            } label: {
                Text("library.guest.signIn".localized)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [.brandGradientStart, .brandGradientMiddle, .brandGradientEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }

            NavigationLink(destination: DiscoverView()) {
                Text("library.guest.browseFirst".localized)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(20)
        .background(Color.backgroundSubtle)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.brandLavender)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Display Item for unified view

struct BrowsingHistoryDisplayItem: Identifiable {
    let id: String
    let title: String
    let author: String
    let coverUrl: String?
    let coverThumbUrl: String?
    var browsedAt: Date = Date()

    var displayCoverUrl: String? {
        coverThumbUrl ?? coverUrl
    }

    /// Returns title - should be pre-localized by server based on Accept-Language header
    var localizedTitle: String {
        title
    }

    /// Returns author - should be pre-localized by server based on Accept-Language header
    var localizedAuthor: String {
        author
    }
}

// MARK: - Grid Card V2 (for unified display item)

struct RecentlyBrowsedGridCardV2: View {
    let item: BrowsingHistoryDisplayItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            Color.clear
                .aspectRatio(2/3, contentMode: .fit)
                .overlay(
                    Group {
                        if let urlString = item.displayCoverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                            KFImage(url)
                                .loadDiskFileSynchronously()
                                .placeholder { _ in ProgressView() }
                                .fade(duration: 0.25)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.3))
                                .overlay(
                                    Image(systemName: "book.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        }
                    }
                )
                .clipped()
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title
            Text(item.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(height: 34, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Book Detail View By ID

struct BookDetailViewById: View {
    let bookId: String
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var book: Book?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let book = book {
                BookDetailView(book: book)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error ?? "common.error".localized)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await loadBook()
        }
    }

    private func loadBook() async {
        isLoading = true

        do {
            let detail: BookDetail = try await APIClient.shared.request(
                endpoint: APIEndpoints.bookDetail(bookId)
            )
            book = detail.book
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
