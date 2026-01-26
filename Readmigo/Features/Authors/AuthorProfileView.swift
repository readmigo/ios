import SwiftUI
import Kingfisher
import SafariServices

// MARK: - Author Era Gradient

/// Determines the gradient colors based on the author's literary era
enum AuthorEra {
    case classical      // pre-1800
    case romanticism    // 1800-1850
    case victorian      // 1850-1900
    case modern         // 1900-1950
    case contemporary   // 1950+

    /// Parse era from author's era string (e.g., "1775-1817")
    static func from(eraString: String?) -> AuthorEra {
        guard let era = eraString else { return .contemporary }

        // Extract the first year from the era string
        let numbers = era.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
            .filter { $0 > 1000 && $0 < 2100 }

        guard let birthYear = numbers.first else { return .contemporary }

        switch birthYear {
        case ..<1800: return .classical
        case 1800..<1850: return .romanticism
        case 1850..<1900: return .victorian
        case 1900..<1950: return .modern
        default: return .contemporary
        }
    }

    /// Gradient colors for the era
    var gradientColors: [Color] {
        switch self {
        case .classical:
            // Warm brown - classic literature feel
            return [Color(hex: "8B4513"), Color(hex: "654321")]
        case .romanticism:
            // Elegant gray - romantic period
            return [Color(hex: "4A5568"), Color(hex: "2D3748")]
        case .victorian:
            // Vintage gold-brown - Victorian era
            return [Color(hex: "744210"), Color(hex: "553C2D")]
        case .modern:
            // Deep blue - modernist movement
            return [Color(hex: "1A365D"), Color(hex: "2A4365")]
        case .contemporary:
            // Modern black - contemporary style
            return [Color(hex: "1F2937"), Color(hex: "111827")]
        }
    }

    /// Display name for the era
    var displayName: String {
        switch self {
        case .classical: return "authorEra.classical".localized
        case .romanticism: return "authorEra.romanticism".localized
        case .victorian: return "authorEra.victorian".localized
        case .modern: return "authorEra.modern".localized
        case .contemporary: return "authorEra.contemporary".localized
        }
    }
}

/// Full author profile view with bio, timeline, quotes, and books
struct AuthorProfileView: View {
    let authorId: String
    let presentedAsFullScreen: Bool
    @StateObject private var manager = AuthorManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingBook: BookSummary?

    // Swipe to dismiss state
    @State private var dragOffset: CGFloat = 0
    @State private var isDraggingToDismiss = false
    private let dismissThreshold: CGFloat = 150

    // Animation states
    @State private var showHeroBackground = false
    @State private var showAvatar = false
    @State private var showName = false
    @State private var showMeta = false
    @State private var showStats = false
    @State private var showSections = false

    // Bio expansion state
    @State private var isBioExpanded = true

    // Wikipedia in-app browser state
    @State private var showWikipedia = false
    @State private var wikipediaURL: URL?

    // Quotes section expansion state
    @State private var isQuotesExpanded = true

    init(authorId: String, presentedAsFullScreen: Bool = false) {
        self.authorId = authorId
        self.presentedAsFullScreen = presentedAsFullScreen
    }

    private let avatarColors: [Color] = [
        Color(red: 0.91, green: 0.30, blue: 0.24),
        Color(red: 0.90, green: 0.49, blue: 0.13),
        Color(red: 0.18, green: 0.80, blue: 0.44),
        Color(red: 0.20, green: 0.60, blue: 0.86),
        Color(red: 0.56, green: 0.27, blue: 0.68),
        Color(red: 0.10, green: 0.74, blue: 0.61),
        Color(red: 0.95, green: 0.77, blue: 0.06),
        Color(red: 0.40, green: 0.50, blue: 0.60),
    ]

    var body: some View {
        Group {
            if presentedAsFullScreen {
                fullScreenContent
            } else {
                mainContent
                    .navigationTitle(manager.currentAuthorDetail?.localizedName ?? "author.title".localized)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .sheet(isPresented: $showWikipedia) {
            if let url = wikipediaURL {
                AuthorSafariView(url: url)
            }
        }
        .task {
            await manager.fetchAuthorDetail(authorId)
            await manager.fetchRelatedAuthors(authorId)
            await manager.fetchReadingProgress(authorId)
        }
    }

    @ViewBuilder
    private var fullScreenContent: some View {
        GeometryReader { geometry in
            NavigationStack {
                mainContent
                    .navigationTitle(manager.currentAuthorDetail?.localizedName ?? "author.title".localized)
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

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            if manager.isLoadingDetail && manager.currentAuthorDetail == nil {
                ProgressView("common.loading".localized)
            } else if let author = manager.currentAuthorDetail {
                ScrollView {
                    VStack(spacing: 24) {
                        // Offline banner when viewing cached data
                        if manager.dataSource == .cache {
                            OfflineBannerView(lastSyncTime: manager.lastSyncTime) {
                                Task {
                                    await manager.fetchAuthorDetail(authorId)
                                }
                            }
                        }

                        // Header (Avatar + Name + Followers + Follow)
                        authorHeader(author)

                        // Literary Profile Section (Combined: Author Info + Writing Style + Civilization Map)
                        literaryProfileSection(author)
                            .opacity(showSections ? 1 : 0)
                            .offset(y: showSections ? 0 : 20)
                            .animation(.easeOut(duration: 0.4).delay(0.05), value: showSections)

                        // Quotes Section (All quotes with expand/collapse)
                        if !author.quotes.isEmpty {
                            quotesListSection(author)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.1), value: showSections)
                        }

                        // Bio Section with animation
                        if let bio = author.bio {
                            bioSection(bio, wikipediaUrl: author.wikipediaUrl)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.15), value: showSections)
                        }

                        // Famous Works Section with animation
                        if !author.famousWorks.isEmpty {
                            famousWorksSection(author.famousWorks)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.2), value: showSections)
                        }

                        // Timeline Section with animation
                        if !author.timelineEvents.isEmpty {
                            timelineSection(author.timelineEvents)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.25), value: showSections)
                        }

                        // Reading Challenge Section with animation
                        if let progress = manager.readingProgress, progress.totalBooks > 0 {
                            readingChallengeSection(author, progress: progress)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.3), value: showSections)
                        }

                        // Books Section with animation
                        if !author.books.isEmpty {
                            booksSection(author.books, readBookIds: manager.readingProgress?.readBookIds ?? [], authorName: author.name)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.35), value: showSections)
                        }

                        // Related Authors Section with animation
                        if !manager.relatedAuthors.isEmpty {
                            relatedAuthorsSection(manager.relatedAuthors)
                                .opacity(showSections ? 1 : 0)
                                .offset(y: showSections ? 0 : 20)
                                .animation(.easeOut(duration: 0.4).delay(0.5), value: showSections)
                        }

                    }
                    .padding()
                }
            } else {
                Text("author.notFound".localized)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Header (Simplified: Avatar + Name + Followers + Follow Button)

    @ViewBuilder
    private func authorHeader(_ author: AuthorDetail) -> some View {
        let authorEra = AuthorEra.from(eraString: author.era)

        ZStack {
            // Era-based gradient background
            LinearGradient(
                colors: authorEra.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(showHeroBackground ? 1 : 0)

            // Paper texture overlay
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .background(
                    Image(systemName: "doc.text")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .foregroundColor(.white.opacity(0.03))
                )

            VStack(spacing: 16) {
                // Avatar with animation
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 120, height: 120)

                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 3)
                        .frame(width: 120, height: 120)

                    if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
                        KFImage(url)
                            .placeholder {
                                Text(author.initials)
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .fade(duration: 0.25)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 110, height: 110)
                            .clipShape(Circle())
                    } else {
                        Text(author.initials)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                .scaleEffect(showAvatar ? 1 : 0.5)
                .opacity(showAvatar ? 1 : 0)

                // Name with animation
                VStack(spacing: 4) {
                    Text(author.localizedName.uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .tracking(2)
                }
                .opacity(showName ? 1 : 0)
                .offset(y: showName ? 0 : 10)

                // Follower count
                if author.followerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                        Text(String(format: "author.followersCount".localized, author.followerCount))
                            .font(.caption)
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showStats ? 1 : 0)
                }

                // Like Button
                Button {
                    Task {
                        if author.isFollowed {
                            await manager.unfollowAuthor(authorId)
                        } else {
                            await manager.followAuthor(authorId)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: author.isFollowed ? "heart.fill" : "heart")
                        Text(author.isFollowed ? "author.liked".localized : "author.like".localized)
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(author.isFollowed ? .red : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(author.isFollowed ? Color.white.opacity(0.9) : Color.white.opacity(0.2))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }
                .opacity(showStats ? 1 : 0)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(20)
        .shadow(color: authorEra.gradientColors[0].opacity(0.3), radius: 15, x: 0, y: 8)
        .onAppear {
            startHeroAnimations()
        }
    }

    // MARK: - Literary Profile Section (Combined: Author Info + Writing Style + Civilization Map)

    @ViewBuilder
    private func literaryProfileSection(_ author: AuthorDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .foregroundColor(.blue)
                Text("author.literaryProfile".localized)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 20) {
                // 1. Basic Info Grid
                basicInfoGrid(author)

                // 2. Literary Position (Movement + Period)
                if author.civilizationMap?.literaryMovement != nil || author.literaryPeriod != nil || author.civilizationMap?.historicalPeriod != nil {
                    literaryPositionSection(author)
                }

                // 3. Primary Genres
                if let genres = author.civilizationMap?.primaryGenres, !genres.isEmpty {
                    tagSection(title: "civilizationMap.primaryGenres".localized, tags: genres, color: .blue)
                }

                // 4. Core Themes
                if let themes = author.civilizationMap?.themes, !themes.isEmpty {
                    tagSection(title: "civilizationMap.themes".localized, tags: themes, color: .secondary)
                }

                // 5. Cross-Domain Contributions (Optional)
                if let domains = author.civilizationMap?.domains, !domains.isEmpty {
                    crossDomainSection(domains)
                }

                // 7. Historical Context (Optional)
                if let events = author.civilizationMap?.historicalContext, !events.isEmpty {
                    historicalContextSection(Array(events.prefix(4)))
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Literary Profile Sub-components

    @ViewBuilder
    private func basicInfoGrid(_ author: AuthorDetail) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            // Era
            if let era = author.era {
                compactInfoItem(icon: "calendar", label: "author.era".localized, value: era)
            }

            // Nationality
            if let nationality = author.nationality {
                compactInfoItem(icon: "globe", label: "author.nationality".localized, value: nationality)
            }

            // Birth Place
            if let birthPlace = author.birthPlace {
                compactInfoItem(icon: "mappin.and.ellipse", label: "author.birthPlace".localized, value: birthPlace)
            }

            // Book Count
            compactInfoItem(icon: "book.fill", label: "author.works".localized, value: "\(author.bookCount)")
        }
    }

    private func compactInfoItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            Spacer()
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func literaryPositionSection(_ author: AuthorDetail) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("civilizationMap.literaryPosition".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                if let movement = author.civilizationMap?.literaryMovement {
                    HStack {
                        Text("civilizationMap.literaryMovement".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(movement)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }

                if let period = author.literaryPeriod ?? author.civilizationMap?.historicalPeriod {
                    HStack {
                        Text("author.literaryPeriod".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        Text(period)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func tagSection(title: String, tags: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(color == .blue ? Color.blue.opacity(0.1) : Color(.systemGray5))
                        .foregroundColor(color == .blue ? .blue : .primary)
                        .cornerRadius(12)
                }
            }
        }
    }

    @ViewBuilder
    private func crossDomainSection(_ domains: [DomainPosition]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("civilizationMap.crossDomain".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(domains.prefix(3)) { domain in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(domain.localizedDomain)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            significanceBadge(domain.significance)
                        }

                        ForEach(domain.localizedContributions.prefix(2), id: \.self) { contribution in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.secondary)
                                    .frame(width: 4, height: 4)
                                    .padding(.top, 6)
                                Text(contribution)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }

    private func significanceBadge(_ significance: DomainSignificance) -> some View {
        Text(significance.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(significance == .major ? Color.blue : Color(.systemGray5))
            .foregroundColor(significance == .major ? .white : .secondary)
            .cornerRadius(4)
    }

    @ViewBuilder
    private func historicalContextSection(_ events: [CivilizationHistoricalEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("civilizationMap.historicalContext".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(historicalEventColor(event.category))
                                .frame(width: 8, height: 8)

                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 1)
                                    .frame(maxHeight: .infinity)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("\(event.year)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(historicalEventColor(event.category))
                                Text(event.category.displayName)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(3)
                            }
                            Text(event.localizedTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, index < events.count - 1 ? 12 : 0)

                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
    }

    private func historicalEventColor(_ category: HistoricalEventCategory) -> Color {
        switch category {
        case .war: return .red
        case .revolution: return .orange
        case .cultural: return .purple
        case .political: return .blue
        case .scientific: return .green
        }
    }

    // MARK: - Quotes Section (All Quotes with Expand/Collapse)

    @ViewBuilder
    private func quotesListSection(_ author: AuthorDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with expand/collapse toggle
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isQuotesExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("author.famousQuotes".localized)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if author.quoteCount > 0 {
                        Text(String(format: "author.quotesCount".localized, author.quoteCount))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(8)
                    }

                    Image(systemName: isQuotesExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Quotes list (collapsible)
            if isQuotesExpanded && !author.quotes.isEmpty {
                VStack(spacing: 12) {
                    ForEach(author.quotes) { quote in
                        quoteItemView(quote)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quoteItemView(_ quote: AuthorQuote) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 4) {
                Text("❝")
                    .font(.title2)
                    .foregroundColor(.orange.opacity(0.5))

                Text(quote.text)
                    .font(.custom("Georgia", size: 15))
                    .italic()
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }

            HStack {
                if let source = quote.source {
                    Text("— \(source)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Like count
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red.opacity(0.7))
                    Text("\(quote.likeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.leading, 24)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.08), Color.yellow.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(10)
    }

    /// Trigger hero section animations sequentially
    private func startHeroAnimations() {
        withAnimation(.easeOut(duration: 0.3)) {
            showHeroBackground = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
            showAvatar = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.4)) {
            showName = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
            showMeta = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.6)) {
            showStats = true
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.7)) {
            showSections = true
        }
    }

    private func statItem(value: Int, label: String, light: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(light ? .white : .primary)
            Text(label)
                .font(.caption)
                .foregroundColor(light ? .white.opacity(0.8) : .secondary)
        }
    }

    // MARK: - Bio Section

    @ViewBuilder
    private func bioSection(_ bio: String, wikipediaUrl: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("author.aboutTitle".localized)
                .font(.headline)

            ZStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(bio)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                        .lineLimit(isBioExpanded ? nil : 4)
                }

                // Gradient mask for collapsed state
                if !isBioExpanded {
                    LinearGradient(
                        colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }
            }

            // Read More / Read Less button and Wikipedia link
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isBioExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(isBioExpanded ? "button.readLess".localized : "button.readMore".localized)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: isBioExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                // Wikipedia link (opens in-app browser)
                if let urlString = wikipediaUrl, let url = URL(string: urlString) {
                    Button {
                        wikipediaURL = url
                        showWikipedia = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("Wikipedia")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Famous Works Section

    @ViewBuilder
    private func famousWorksSection(_ works: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("author.majorWorks".localized)
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(works, id: \.self) { work in
                    Text(work)
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Timeline Section

    @ViewBuilder
    private func timelineSection(_ events: [AuthorTimelineEvent]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("author.lifeAndWorks".localized)
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(events) { event in
                    timelineEventRow(event, isLast: event.id == events.last?.id)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineEventRow(_ event: AuthorTimelineEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline line and dot
            VStack(spacing: 0) {
                Circle()
                    .fill(timelineColor(for: event.category))
                    .frame(width: 12, height: 12)

                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(event.year)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(timelineColor(for: event.category))

                    Image(systemName: event.category.icon)
                        .font(.caption)
                        .foregroundColor(timelineColor(for: event.category))
                }

                Text(event.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description = event.localizedDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 16)

            Spacer()
        }
    }

    private func timelineColor(for category: AuthorTimelineEvent.TimelineCategory) -> Color {
        switch category {
        case .birth: return .yellow
        case .education: return .blue
        case .work: return .green
        case .majorEvent: return .purple
        case .award: return .orange
        case .death: return .gray
        }
    }

    // MARK: - Reading Challenge Section

    @ViewBuilder
    private func readingChallengeSection(_ author: AuthorDetail, progress: AuthorReadingProgress) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("author.readingChallenge".localized)
                    .font(.headline)
                Spacer()
                if progress.isComplete {
                    Text("author.challengeComplete".localized)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.green)
                        .cornerRadius(12)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                // Progress text
                HStack {
                    Text(String(format: "author.readAllBooks".localized, author.localizedName))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(progress.booksRead) / \(progress.totalBooks)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(progress.isComplete ? .green : .primary)
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(.systemGray5))
                            .frame(height: 12)

                        // Progress fill
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: progress.isComplete
                                        ? [.green, .mint]
                                        : [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(progress.progress), height: 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress.progress)
                    }
                }
                .frame(height: 12)

                // Badge unlock hint
                if !progress.isComplete {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("author.unlockBadgeHint".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("author.allBooksRead".localized)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Books Section

    @ViewBuilder
    private func booksSection(_ books: [BookSummary], readBookIds: [String], authorName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with "View All" link
            HStack {
                Text(String(format: "author.worksBy".localized, authorName))
                    .font(.headline)

                Spacer()

                if books.count > 4 {
                    NavigationLink {
                        AuthorBooksListView(books: books, authorName: authorName, readBookIds: readBookIds)
                    } label: {
                        HStack(spacing: 4) {
                            Text("button.viewAll".localized)
                                .font(.subheadline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
            }

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(books) { book in
                        NavigationLink {
                            BookDetailLoaderView(bookId: book.id)
                        } label: {
                            bookCard(book, isRead: readBookIds.contains(book.id))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func bookCard(_ book: BookSummary, isRead: Bool) -> some View {
        let coverWidth: CGFloat = 100
        let coverHeight: CGFloat = 150 // 2:3 aspect ratio

        return VStack(alignment: .leading, spacing: 8) {
            // Cover with fixed size container
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: coverWidth, height: coverHeight)
                    .overlay(
                        KFImage(URL(string: book.coverUrl ?? ""))
                            .placeholder {
                                Image(systemName: "book.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 4)

                // Read badge
                if isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .background(Circle().fill(.white).padding(2))
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: coverWidth, height: coverHeight)

            Text(book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(isRead ? .secondary : .primary)
                .frame(width: coverWidth, alignment: .leading)
        }
        .frame(width: coverWidth)
    }

    // MARK: - Related Authors Section

    @ViewBuilder
    private func relatedAuthorsSection(_ authors: [Author]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("author.relatedAuthors".localized)
                    .font(.headline)

                Spacer()

                Text("author.similarEraStyle".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(authors) { author in
                        relatedAuthorCard(author)
                    }
                }
            }
        }
    }

    private func relatedAuthorCard(_ author: Author) -> some View {
        let cardWidth: CGFloat = 100
        let cardHeight: CGFloat = 180 // Fixed height for consistent sizing

        return NavigationLink {
            AuthorProfileView(authorId: author.id)
        } label: {
            VStack(spacing: 8) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarColors[author.avatarColorIndex])
                        .frame(width: 60, height: 60)

                    if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
                        KFImage(url)
                            .placeholder {
                                Text(author.initials)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    } else {
                        Text(author.initials)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                // Name (fixed 2 lines)
                Text(author.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32) // Fixed height for 2 lines

                // Era badge (always show, use placeholder if empty)
                Text(author.era ?? "—")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .lineLimit(1)

                // Book count
                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.caption2)
                    Text(String(format: "author.booksCountSmall".localized, author.bookCount))
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            .frame(width: cardWidth, height: cardHeight)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }

}

// MARK: - Book Detail Loader View (loads book by ID)

struct BookDetailLoaderView: View {
    let bookId: String
    @EnvironmentObject var libraryManager: LibraryManager
    @State private var book: Book?
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("common.loading".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let book = book {
                BookDetailView(book: book)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text(error ?? "book.notFound".localized)
                        .foregroundColor(.secondary)
                }
            }
        }
        .task {
            await loadBook()
        }
    }

    private func loadBook() async {
        isLoading = true
        do {
            let bookDetail: BookDetail = try await APIClient.shared.request(
                endpoint: APIEndpoints.bookDetail(bookId)
            )
            self.book = bookDetail.book
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Author Books List View (View All)

struct AuthorBooksListView: View {
    let books: [BookSummary]
    let authorName: String
    let readBookIds: [String]

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 20
            ) {
                ForEach(books) { book in
                    NavigationLink {
                        BookDetailLoaderView(bookId: book.id)
                    } label: {
                        authorBookGridCard(book, isRead: readBookIds.contains(book.id))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(String(format: "author.booksBy".localized, authorName))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func authorBookGridCard(_ book: BookSummary, isRead: Bool) -> some View {
        let coverWidth: CGFloat = 100
        let coverHeight: CGFloat = 150 // 2:3 aspect ratio

        return VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: coverWidth, height: coverHeight)
                    .overlay(
                        KFImage(URL(string: book.coverUrl ?? ""))
                            .placeholder {
                                Image(systemName: "book.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            }
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                if isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                        .background(Circle().fill(.white).padding(2))
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: coverWidth, height: coverHeight)

            Text(book.localizedTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .foregroundColor(isRead ? .secondary : .primary)
                .frame(width: coverWidth, alignment: .leading)
        }
        .frame(width: coverWidth)
    }
}

// MARK: - Safari View (In-App Browser)

private struct AuthorSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
