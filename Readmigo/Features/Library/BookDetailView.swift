import SwiftUI
import Kingfisher

// MARK: - String Extension for Sheet Binding

extension String: @retroactive Identifiable {
    public var id: String { self }
}

struct BookDetailView: View {
    let book: Book
    let presentedAsFullScreen: Bool
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var browsingHistoryManager: BrowsingHistoryManager
    @Environment(\.dismiss) private var dismiss
    @State private var bookDetail: BookDetail?
    @State private var isLoading = true
    @State private var isInLibrary = false
    @State private var showingReader = false
    @State private var dataSource: DataSourceType = .network
    @State private var lastSyncTime: Date?

    // Guest mode login prompt
    @State private var showLoginPrompt = false
    @State private var loginPromptFeature = ""

    // Audiobook state
    @State private var linkedAudiobook: Audiobook?
    @State private var showAudiobookPlayer = false
    @StateObject private var audiobookPlayer = AudiobookPlayer.shared

    // Swipe to dismiss state
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingToDismiss = false
    private let dismissThreshold: CGFloat = 150

    // Immersive navigation state (iOS 18+)
    @State private var scrollOffset: CGFloat = 0

    // Calculate title opacity based on scroll position
    private var titleOpacity: Double {
        let fadeStart: CGFloat = 250  // Start fading in after header mostly scrolled
        let fadeEnd: CGFloat = 350    // Fully visible
        return min(1, max(0, (scrollOffset - fadeStart) / (fadeEnd - fadeStart)))
    }

    enum DataSourceType {
        case network
        case cache
    }

    init(book: Book, presentedAsFullScreen: Bool = false) {
        self.book = book
        self.presentedAsFullScreen = presentedAsFullScreen
    }

    var body: some View {
        Group {
            if presentedAsFullScreen {
                fullScreenContent
            } else {
                if #available(iOS 18.0, *) {
                    immersiveContent
                } else {
                    standardContent
                        .navigationTitle(book.localizedTitle)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .fullScreenCover(isPresented: $showingReader) {
            // Use bookDetail if already loaded, otherwise ReaderViewModel will load it
            if let detail = bookDetail {
                EnhancedReaderView(viewModel: ReaderViewModel(book: book, bookDetail: detail))
                    .environmentObject(ThemeManager.shared)
            } else {
                // Book detail not loaded yet - reader will load it itself
                EnhancedReaderView(viewModel: ReaderViewModel(book: book))
                    .environmentObject(ThemeManager.shared)
            }
        }
        .fullScreenCover(isPresented: $showAudiobookPlayer) {
            AudiobookPlayerView()
        }
        .task {
            await loadBookDetail()
            isInLibrary = libraryManager.getUserBook(id: book.id) != nil
            await loadLinkedAudiobook()

            // Record browsing history (works for both guest and authenticated users)
            await browsingHistoryManager.addBook(book)
        }
        .loginPrompt(isPresented: $showLoginPrompt, feature: loginPromptFeature)
    }

    // MARK: - Guest Mode Helpers

    private func requireLoginForLibrary() -> Bool {
        if authManager.isAuthenticated {
            return true
        } else {
            loginPromptFeature = "library"
            showLoginPrompt = true
            return false
        }
    }

    private func requireLoginForDownload() -> Bool {
        if authManager.isAuthenticated {
            return true
        } else {
            loginPromptFeature = "download"
            showLoginPrompt = true
            return false
        }
    }

    @ViewBuilder
    private var fullScreenContent: some View {
        GeometryReader { geometry in
            NavigationStack {
                standardContent
                    .navigationTitle(book.localizedTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.hidden, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemName: "chevron.down")
                                    .font(.body.weight(.semibold))
                                    .foregroundColor(.primary)
                            }
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(Color(.systemBackground))
            .cornerRadius(dragOffset > 0 ? 20 : 0)
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            isDraggingToDismiss = true
                            let resistance: CGFloat = 0.6
                            dragOffset = value.translation.height * resistance
                        }
                    }
                    .onEnded { value in
                        if dragOffset > dismissThreshold {
                            withAnimation(.easeOut(duration: 0.25)) {
                                dragOffset = geometry.size.height
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                dismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                        }
                        isDraggingToDismiss = false
                    }
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - iOS 18+ Immersive Content

    @available(iOS 18.0, *)
    @ViewBuilder
    private var immersiveContent: some View {
        ZStack(alignment: .top) {
            // Main scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Immersive header with cover (with scroll animations)
                    BookDetailHeaderImmersive(book: book, scrollOffset: scrollOffset)

                    // Offline banner when viewing cached data
                    if dataSource == .cache {
                        OfflineBannerView(lastSyncTime: lastSyncTime) {
                            Task {
                                await loadBookDetail()
                            }
                        }
                        .padding()
                    }

                    // Content sections
                    contentSections
                        .background(
                            Group {
                                #if DEBUG
                                GeometryReader { geo in
                                    Color.clear
                                        .onAppear {
                                            LoggingService.shared.debug(.books, "DEBUG_LAYOUT: Book '\(book.title)' content width: \(geo.size.width)", component: "BookDetailView")
                                        }
                                        .onChange(of: geo.size.width) { _, newWidth in
                                            LoggingService.shared.debug(.books, "DEBUG_LAYOUT: Book '\(book.title)' content width changed to: \(newWidth)", component: "BookDetailView")
                                        }
                                }
                                #else
                                Color.clear
                                #endif
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity)
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, newValue in
                scrollOffset = newValue
            }
            .ignoresSafeArea(edges: .top)

            // Custom navigation bar overlay
            ImmersiveNavigationBar(
                title: book.localizedTitle,
                titleOpacity: titleOpacity,
                onBack: { dismiss() }
            )
        }
        .navigationBarHidden(true)
        .enableSwipeBack()
    }

    // MARK: - Standard Content (iOS 17 and below)

    @ViewBuilder
    private var standardContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Offline banner when viewing cached data
                if dataSource == .cache {
                    OfflineBannerView(lastSyncTime: lastSyncTime) {
                        Task {
                            await loadBookDetail()
                        }
                    }
                    .padding()
                }

                // Header with Cover
                BookDetailHeader(book: book, onAuthorTap: nil)

                // Content sections
                contentSections
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Shared Content Sections

    @ViewBuilder
    private var contentSections: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Action Buttons
            ActionButtonsSection(
                book: book,
                onRead: {
                    // Auto-add to library when starting to read
                    if !isInLibrary && authManager.isAuthenticated {
                        Task {
                            try? await libraryManager.addToLibrary(bookId: book.id, status: .reading)
                            isInLibrary = true
                        }
                    }
                    showingReader = true
                }
            )

            // Audiobook Section
            if book.hasAudiobook == true || linkedAudiobook != nil {
                AudiobookEntrySection(
                    audiobook: linkedAudiobook,
                    onPlay: {
                        if let audiobook = linkedAudiobook {
                            // Auto-add to library when playing audiobook
                            if !isInLibrary && authManager.isAuthenticated {
                                Task {
                                    try? await libraryManager.addToLibrary(bookId: book.id, status: .reading)
                                    isInLibrary = true
                                }
                            }
                            audiobookPlayer.loadAndPlay(audiobook: audiobook)
                            showAudiobookPlayer = true
                        }
                    }
                )
            }

            // Author Link (as NavigationLink)
            AuthorNavigationSection(authorName: book.author, authorId: book.authorId)

            // Description
            if let description = book.description {
                DescriptionSection(text: description)
            }

            // Reading Guide (阅读指南)
            ReadingGuideSection(bookId: book.id)

            // Skill Bucket Preview (能力木桶图预览) - Hidden
            // SkillBucketPreviewSection(bookId: book.id)

            // Book Context (Creation Background, Historical Context, Themes)
            BookContextSection(bookId: book.id)

            // Chapters
            if let detail = bookDetail {
                ChaptersSection(chapters: detail.chapters)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private func loadBookDetail() async {
        isLoading = true

        let cacheKey = CacheKeys.bookDetailKey(book.id)
        let cacheService = ResponseCacheService.shared

        do {
            bookDetail = try await APIClient.shared.request(
                endpoint: APIEndpoints.bookDetail(book.id)
            )

            // Cache the response
            if let detail = bookDetail {
                await cacheService.set(detail, for: cacheKey, ttl: .bookDetail)
            }
            dataSource = .network
            lastSyncTime = Date()
        } catch {
            // Try to load from cache on network failure
            if let cachedDetail: BookDetail = await cacheService.get(cacheKey, type: BookDetail.self) {
                bookDetail = cachedDetail
                if let cachedAt = await cacheService.getCachedResponse(cacheKey)?.timestamp {
                    lastSyncTime = cachedAt
                }
                dataSource = .cache
                LoggingService.shared.info(.books, "Loaded book detail from cache: \(book.id)")
            } else {
                print("Failed to load book detail: \(error)")
            }
        }
        isLoading = false
    }

    private func addToLibrary(status: BookStatus) async {
        do {
            try await libraryManager.addToLibrary(bookId: book.id, status: status)
            isInLibrary = true
        } catch {
            print("Failed to add to library: \(error)")
        }
    }

    private func updateBookStatus(status: BookStatus) async {
        do {
            try await libraryManager.updateBookStatus(bookId: book.id, status: status)
        } catch {
            print("Failed to update book status: \(error)")
        }
    }

    private func removeFromLibrary() async {
        do {
            try await libraryManager.removeFromLibrary(bookId: book.id)
            isInLibrary = false
        } catch {
            print("Failed to remove from library: \(error)")
        }
    }

    private func loadLinkedAudiobook() async {
        // Check if book has audiobook via hasAudiobook field or audiobookId
        if book.hasAudiobook == true || book.audiobookId != nil {
            // Use WhispersyncManager to get the audiobook for this book
            linkedAudiobook = await WhispersyncManager.shared.getAudiobook(for: book.id)
        }
    }
}

// MARK: - Audiobook Entry Section

struct AudiobookEntrySection: View {
    let audiobook: Audiobook?
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "headphones")
                    .foregroundColor(.accentColor)
                Text("audiobook.available".localized)
                    .font(.headline)
            }

            Button(action: onPlay) {
                HStack(spacing: 12) {
                    // Audiobook icon
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "play.fill")
                            .foregroundColor(.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("audiobook.listenNow".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)

                        if let audiobook = audiobook {
                            HStack(spacing: 8) {
                                if let narrator = audiobook.narrator {
                                    Text(narrator)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(audiobook.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("audiobook.loading".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .disabled(audiobook == nil)
        }
    }
}

// MARK: - Reader Loading Fallback View

struct ReaderLoadingFallbackView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("common.loading".localized)
                    .foregroundColor(.secondary)
            }

            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
        }
    }
}

// MARK: - Header

struct BookDetailHeader: View {
    let book: Book
    var onAuthorTap: ((String) -> Void)?

    /// Parse author string into individual author names
    private var authors: [String] {
        // Handle multiple separators: ", ", " and ", " & ", ";"
        var authorString = book.author

        // Replace various separators with a common one
        authorString = authorString.replacingOccurrences(of: " and ", with: "|||")
        authorString = authorString.replacingOccurrences(of: " & ", with: "|||")
        authorString = authorString.replacingOccurrences(of: "; ", with: "|||")
        authorString = authorString.replacingOccurrences(of: ", ", with: "|||")

        // Split and clean up
        return authorString
            .split(separator: "|||")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Background Blur (with Kingfisher caching)
            Group {
                if let urlString = book.coverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.3)
                }
            }
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [.clear, Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blur(radius: 20)

            // Cover and Title (with Kingfisher caching)
            VStack(spacing: 16) {
                Color.clear
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(maxWidth: 200)
                    .overlay(
                        Group {
                            if let urlString = book.coverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                                KFImage(url)
                                    .placeholder { _ in
                                        ProgressView()
                                    }
                                    .fade(duration: 0.25)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .overlay(
                                        Image(systemName: "book.fill")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    )
                    .clipped()
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                VStack(spacing: 8) {
                    Text(book.localizedTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)

                    HStack(spacing: 16) {
                        if let wordCount = book.wordCount {
                            Label(String(format: "book.wordsK".localized, wordCount / 1000), systemImage: "doc.text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Author Links View

struct AuthorLinksView: View {
    let authors: [String]
    var onAuthorTap: ((String) -> Void)?

    var body: some View {
        if authors.count == 1 {
            // Single author
            AuthorLinkButton(name: authors[0], onTap: onAuthorTap)
        } else if authors.count == 2 {
            // Two authors: "Author1 & Author2"
            HStack(spacing: 4) {
                AuthorLinkButton(name: authors[0], onTap: onAuthorTap)
                Text("&")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                AuthorLinkButton(name: authors[1], onTap: onAuthorTap)
            }
        } else {
            // Multiple authors: wrap in a flow layout
            FlowLayout(spacing: 4) {
                ForEach(Array(authors.enumerated()), id: \.offset) { index, author in
                    HStack(spacing: 4) {
                        AuthorLinkButton(name: author, onTap: onAuthorTap)
                        if index < authors.count - 1 {
                            Text(",")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Author Link Button

struct AuthorLinkButton: View {
    let name: String
    var onTap: ((String) -> Void)?

    @State private var isPressed = false

    var body: some View {
        Button {
            onTap?(name)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.caption2)

                Text(name)
                    .underline()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.blue)
        }
        .buttonStyle(AuthorButtonStyle())
        .accessibilityLabel(String(format: "accessibility.viewBooksBy".localized, name))
        .accessibilityHint("accessibility.openAuthorBooks".localized)
    }
}

// MARK: - Author Button Style

struct AuthorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Action Buttons

struct ActionButtonsSection: View {
    let book: Book
    let onRead: () -> Void

    var body: some View {
        // Read Button - always enabled, loading happens inside reader
        Button(action: onRead) {
            HStack {
                Image(systemName: "book")
                Text("book.startReading".localized)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Description

struct DescriptionSection: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("book.about".localized)
                .font(.headline)

            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Book Info

struct BookInfoSection: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("book.details".localized)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                if let publishedAt = book.publishedAt {
                    let year = Calendar.current.component(.year, from: publishedAt)
                    InfoItem(icon: "calendar", title: "book.published".localized, value: String(year))
                }

                InfoItem(
                    icon: "chart.bar",
                    title: "discover.difficulty".localized,
                    value: difficultyLabel(book.difficultyScore)
                )

                if let wordCount = book.wordCount {
                    InfoItem(icon: "doc.text", title: "book.words.label".localized, value: "\(wordCount / 1000)k")
                }

                if (book.genres ?? []).count > 0 {
                    InfoItem(
                        icon: "tag",
                        title: "book.genre".localized,
                        value: book.localizedFirstGenre ?? ""
                    )
                }
            }

            // Genres Tags
            if !book.localizedGenres.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(book.localizedGenres, id: \.self) { genre in
                        Text(genre)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                }
            }
        }
    }

    private func difficultyLabel(_ score: Double?) -> String {
        guard let score = score else { return "difficulty.unknown".localized }
        switch score {
        case 0..<30: return "difficulty.easy".localized
        case 30..<50: return "difficulty.medium".localized
        case 50..<70: return "difficulty.challenging".localized
        default: return "difficulty.advanced".localized
        }
    }
}

struct InfoItem: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Chapters

struct ChaptersSection: View {
    let chapters: [Chapter]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("book.chaptersCount".localized(with: chapters.count))
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    HStack {
                        Text("\(index + 1).")
                            .foregroundColor(.secondary)
                            .frame(width: 30, alignment: .leading)

                        Text(chapter.title)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let wordCount = chapter.wordCount {
                            Text("book.wordsCount".localized(with: wordCount))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)

                    if index < chapters.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Author Profile Loader View

/// A view that searches for an author by name and displays their profile
struct AuthorProfileLoaderView: View {
    let authorName: String
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var authorId: String?
    @State private var isLoading = true
    @State private var authorNotFound = false

    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("author.loading".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let authorId = authorId {
                AuthorProfileView(authorId: authorId)
            } else {
                // Fallback: show books by this author
                AuthorBooksListFallbackView(authorName: authorName)
                    .environmentObject(libraryManager)
            }
        }
        .navigationTitle(authorName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await searchAuthor()
        }
    }

    private func searchAuthor() async {
        isLoading = true

        // Try different name variations to improve search matching
        let nameVariations = generateNameVariations(authorName)

        for name in nameVariations {
            if let foundAuthorId = await trySearchAuthor(name: name) {
                authorId = foundAuthorId
                isLoading = false
                return
            }
        }

        authorNotFound = true
        isLoading = false
    }

    private func trySearchAuthor(name: String) async -> String? {
        do {
            let searchName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
            let endpoint = "\(APIEndpoints.authors)?search=\(searchName)&limit=5"
            let response: AuthorsResponse = try await APIClient.shared.request(endpoint: endpoint)

            // Try to find best match
            if let exactMatch = response.data.first(where: {
                $0.name.lowercased() == name.lowercased()
            }) {
                return exactMatch.id
            }

            // Return first result if any
            if let first = response.data.first {
                return first.id
            }

            return nil
        } catch {
            return nil
        }
    }

    /// Generate variations of author name for better search matching
    private func generateNameVariations(_ name: String) -> [String] {
        var variations: [String] = [name]

        // Remove periods (e.g., "O. Henry" -> "O Henry")
        let withoutPeriods = name.replacingOccurrences(of: ".", with: "")
        if withoutPeriods != name {
            variations.append(withoutPeriods)
        }

        // Remove periods and extra spaces
        let cleaned = name.replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if !variations.contains(cleaned) {
            variations.append(cleaned)
        }

        // Try just the last word (often the surname)
        let parts = name.split(separator: " ")
        if parts.count > 1, let lastName = parts.last {
            variations.append(String(lastName))
        }

        return variations
    }
}

// MARK: - Author Navigation Section

struct AuthorNavigationSection: View {
    let authorName: String
    let authorId: String?

    @State private var author: Author?

    // Avatar colors for placeholder
    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.95, green: 0.77, blue: 0.06),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.10, green: 0.74, blue: 0.61),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
        Color(red: 0.91, green: 0.12, blue: 0.39),
    ]

    private var initials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts.first?.prefix(1) ?? "")\(parts.last?.prefix(1) ?? "")".uppercased()
        }
        return String(authorName.prefix(2)).uppercased()
    }

    private var avatarColorIndex: Int {
        var hash = 0
        for char in authorName.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return abs(hash) % avatarColors.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("book.author".localized)
                .font(.headline)

            NavigationLink {
                // Only navigate to author profile if authorId is available
                // Do NOT search by name to avoid incorrect author matching
                if let authorId = authorId {
                    AuthorProfileView(authorId: authorId, presentedAsFullScreen: false)
                } else {
                    // Show fallback view with books by this author name
                    AuthorBooksListFallbackView(authorName: authorName)
                }
            } label: {
                HStack(spacing: 12) {
                    // Author Avatar
                    authorAvatarView

                    Text(authorName)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
        .task {
            await loadAuthor()
        }
    }

    @ViewBuilder
    private var authorAvatarView: some View {
        if let avatarUrl = author?.avatarUrl, let url = URL(string: avatarUrl) {
            KFImage(url)
                .placeholder { _ in avatarPlaceholder }
                .fade(duration: 0.25)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(avatarColors[avatarColorIndex])
                .frame(width: 40, height: 40)

            Text(initials)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    @MainActor
    private func loadAuthor() async {
        // Only load author details if authorId is available
        // Do NOT search by name to avoid incorrect author matching
        guard let authorId = authorId else {
            // No authorId - just show placeholder avatar
            return
        }

        let endpoint = APIEndpoints.author(authorId)
        do {
            let authorDetail: AuthorDetail = try await APIClient.shared.request(endpoint: endpoint)
            author = authorDetail.asAuthor
        } catch {
            // Silently fail - we'll show the placeholder
        }
    }
}

// MARK: - Author Books List Fallback View

/// Fallback view when author profile is not found - shows books by this author
struct AuthorBooksListFallbackView: View {
    let authorName: String
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var books: [Book] = []
    @State private var isLoading = true

    private var initials: String {
        let parts = authorName.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts.first?.prefix(1) ?? "")\(parts.last?.prefix(1) ?? "")".uppercased()
        }
        return String(authorName.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [
            Color(red: 0.91, green: 0.30, blue: 0.24),
            Color(red: 0.90, green: 0.49, blue: 0.13),
            Color(red: 0.18, green: 0.80, blue: 0.44),
            Color(red: 0.20, green: 0.60, blue: 0.86),
            Color(red: 0.56, green: 0.27, blue: 0.68),
        ]
        var hash = 0
        for char in authorName.unicodeScalars {
            hash = Int(char.value) &+ (hash << 5) &- hash
        }
        return colors[abs(hash) % colors.count]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Author Header
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(avatarColor)
                        Text(initials)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .frame(width: 80, height: 80)

                    Text(authorName)
                        .font(.title2.bold())

                    Text("author.profileNotAvailable".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                Divider()
                    .padding(.horizontal)

                // Books Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("author.booksBy".localized(with: authorName))
                        .font(.headline)
                        .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if books.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("author.noBooksFound".localized)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(books) { book in
                                NavigationLink {
                                    BookDetailView(book: book)
                                } label: {
                                    FallbackBookCard(book: book)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .task {
            await loadBooks()
        }
    }

    private func loadBooks() async {
        isLoading = true

        // Load all books if needed
        if libraryManager.allBooks.isEmpty {
            await libraryManager.fetchAllBooks()
        }

        // Filter books by author name
        let searchName = authorName.lowercased()
        books = libraryManager.allBooks.filter { book in
            book.author.lowercased().contains(searchName)
        }.sorted { $0.title < $1.title }

        isLoading = false
    }
}

private struct FallbackBookCard: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            Group {
                if let urlString = book.displayCoverUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(2/3, contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .aspectRatio(2/3, contentMode: .fill)
                            .overlay(ProgressView())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(2/3, contentMode: .fill)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        )
                }
            }
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

            // Title
            Text(book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}
