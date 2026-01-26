import SwiftUI
import Kingfisher

struct AudiobookListView: View {
    @StateObject private var manager = AudiobookManager.shared
    @State private var selectedLanguage: String?
    @State private var searchText = ""
    @State private var showLanguagePicker = false
    @State private var isSearchFocused = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Search Bar (inside ScrollView to move with pull-to-refresh)
                    AudiobookSearchBar(
                        text: $searchText,
                        isFocused: $isSearchFocused,
                        onSearch: performSearch
                    )
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                    VStack(spacing: 24) {
                        // Offline Banner
                        if manager.dataSource == .cache {
                            OfflineBannerView(lastSyncTime: manager.lastSyncTime) {
                                Task {
                                    manager.reset()
                                    await manager.fetchAudiobooks()
                                    await manager.fetchRecentlyListened()
                                }
                            }
                        }

                        // Recently Listened Section
                        if !manager.recentlyListened.isEmpty {
                            RecentlyListenedSection(audiobooks: manager.recentlyListened)
                        }

                        // Language Filter - only show when multiple languages available
                        if manager.availableLanguages.count > 1 {
                            LanguageFilterView(
                                languages: manager.availableLanguages,
                                selectedLanguage: $selectedLanguage
                            )
                            .onChange(of: selectedLanguage) { _, newValue in
                                Task {
                                    manager.reset()
                                    await manager.fetchAudiobooks(language: newValue)
                                }
                            }
                        }

                        // Audiobooks Grid
                        if manager.featureNotAvailable {
                            FeatureNotAvailableView(requiredVersion: manager.requiredVersion)
                        } else if manager.isLoading && manager.audiobooks.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if manager.audiobooks.isEmpty {
                            EmptyAudiobooksView()
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredAudiobooks) { audiobook in
                                    AudiobookCard(audiobook: audiobook)
                                        .onAppear {
                                            // Load more when reaching end
                                            if audiobook.id == manager.audiobooks.last?.id {
                                                Task {
                                                    await manager.loadMoreAudiobooks(language: selectedLanguage)
                                                }
                                            }
                                        }
                                }
                            }
                            .padding(.horizontal)

                            if manager.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("audiobook.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .elegantRefreshable {
                manager.reset()
                await manager.fetchAudiobooks(language: selectedLanguage)
                await manager.fetchRecentlyListened()
            }
        }
        .onAppear {
            // Use onAppear with detached Task to prevent SwiftUI task cancellation
            guard manager.audiobooks.isEmpty && !manager.isLoading else { return }
            Task.detached {
                await manager.fetchAudiobooks()
                await manager.fetchRecentlyListened()
                await manager.fetchAvailableLanguages()
            }
        }
    }

    // MARK: - Filtered Audiobooks

    private var filteredAudiobooks: [AudiobookListItem] {
        if searchText.isEmpty {
            return manager.audiobooks
        }
        let query = searchText.lowercased()
        return manager.audiobooks.filter { audiobook in
            audiobook.title.lowercased().contains(query) ||
            audiobook.author.lowercased().contains(query) ||
            (audiobook.narrator?.lowercased().contains(query) ?? false)
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        Task {
            manager.reset()
            await manager.fetchAudiobooks(language: selectedLanguage, search: searchText)
        }
    }
}

// MARK: - Audiobook Search Bar

struct AudiobookSearchBar: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    let onSearch: () -> Void
    @FocusState private var textFieldFocused: Bool

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("audiobook.search".localized, text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($textFieldFocused)
                .onSubmit(onSearch)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .onChange(of: textFieldFocused) { _, newValue in
            isFocused = newValue
        }
        .onTapGesture {
            textFieldFocused = true
        }
    }
}

// MARK: - Recently Listened Section

struct RecentlyListenedSection: View {
    let audiobooks: [AudiobookWithProgress]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("audiobook.recentlyListened".localized)
                .font(.headline)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(audiobooks) { audiobook in
                        RecentlyListenedCard(audiobook: audiobook)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct RecentlyListenedCard: View {
    let audiobook: AudiobookWithProgress
    @StateObject private var player = AudiobookPlayer.shared
    @StateObject private var libraryManager = LibraryManager.shared
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            // Auto-add linked book to library when playing audiobook
            if let bookId = audiobook.bookId, authManager.isAuthenticated {
                let isInLibrary = libraryManager.getUserBook(id: bookId) != nil
                if !isInLibrary {
                    Task {
                        try? await libraryManager.addToLibrary(bookId: bookId, status: .reading)
                    }
                }
            }
            // Play audiobook
            player.loadAndPlay(
                audiobook: audiobook.audiobook,
                startChapter: audiobook.progress?.currentChapter ?? 0,
                startPosition: Double(audiobook.progress?.currentPosition ?? 0)
            )
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Cover Image
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 120, height: 160)
                        .overlay {
                            KFImage(URL(string: audiobook.coverUrl ?? ""))
                                .placeholder {
                                    Image(systemName: "headphones")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Audio badge (top-right)
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "headphones")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(6)

                    // Progress indicator (bottom-right)
                    if audiobook.hasProgress {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("\(Int(audiobook.progressPercentage))%")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(6)
                    }
                }
                .shadow(
                    color: colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.15),
                    radius: 4,
                    x: 0,
                    y: 2
                )

                // Title
                Text(audiobook.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                // Author
                Text(audiobook.author)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 120)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Filter

struct LanguageFilterView: View {
    let languages: [String]
    @Binding var selectedLanguage: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                AudiobookFilterChip(
                    title: "audiobook.allLanguages".localized,
                    isSelected: selectedLanguage == nil
                ) {
                    selectedLanguage = nil
                }

                ForEach(languages, id: \.self) { language in
                    AudiobookFilterChip(
                        title: languageDisplayName(language),
                        isSelected: selectedLanguage == language
                    ) {
                        selectedLanguage = language
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private func languageDisplayName(_ code: String) -> String {
        let locale = Locale.current
        return locale.localizedString(forLanguageCode: code) ?? code.uppercased()
    }
}

struct AudiobookFilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Audiobook Card

struct AudiobookCard: View {
    let audiobook: AudiobookListItem
    @StateObject private var player = AudiobookPlayer.shared
    @StateObject private var libraryManager = LibraryManager.shared
    @EnvironmentObject var authManager: AuthManager
    @State private var showPlayer = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            Task {
                // Fetch full audiobook and play
                if let fullAudiobook = await AudiobookManager.shared.fetchAudiobook(audiobook.id) {
                    // Auto-add linked book to library when playing audiobook
                    if let bookId = fullAudiobook.bookId, authManager.isAuthenticated {
                        let isInLibrary = libraryManager.getUserBook(id: bookId) != nil
                        if !isInLibrary {
                            try? await libraryManager.addToLibrary(bookId: bookId, status: .reading)
                        }
                    }
                    player.loadAndPlay(audiobook: fullAudiobook)
                    showPlayer = true
                }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Cover (1:1 square ratio, LibriVox standard is 300x300)
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .overlay {
                            KFImage(URL(string: audiobook.coverUrl ?? ""))
                                .placeholder {
                                    Image(systemName: "headphones")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Audio badge (top-right)
                    Image(systemName: "headphones")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white)
                        .padding(4)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .padding(4)
                }
                .frame(width: 80, height: 80)
                .shadow(
                    color: colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.black.opacity(0.15),
                    radius: 4,
                    x: 0,
                    y: 2
                )

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(audiobook.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)

                    // Author
                    Text(audiobook.author)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    // Narrator
                    if let narrator = audiobook.narrator {
                        Text("audiobook.narratedBy".localized + " \(narrator)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    // Duration & Badges
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(audiobook.formattedDuration)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)

                        if audiobook.hasBookSync {
                            WhispersyncBadge()
                        }

                        Text("\(audiobook.chapterCount) " + "audiobook.chapters".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(Color.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showPlayer) {
            AudiobookPlayerView()
        }
    }
}

// MARK: - Empty State

struct EmptyAudiobooksView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "headphones")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("audiobook.empty.title".localized)
                .font(.headline)

            Text("audiobook.empty.subtitle".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerRelativeFrame(.vertical)
    }
}

// MARK: - Feature Not Available

struct FeatureNotAvailableView: View {
    let requiredVersion: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("audiobook.featureNotAvailable.title".localized)
                .font(.headline)

            if let version = requiredVersion {
                Text(String(format: "audiobook.featureNotAvailable.version".localized, version))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("audiobook.featureNotAvailable.subtitle".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerRelativeFrame(.vertical)
    }
}
