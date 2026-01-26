import SwiftUI
import Kingfisher

/// Unified book cover component with fixed dimensions based on display style
/// Uses Kingfisher for image caching (memory + disk)
struct BookCoverView: View {
    let coverUrl: String?
    let dimensions: BookCoverDimensions
    let cornerRadius: CGFloat
    let source: String?

    /// Show source badge in all non-production environments
    private var shouldShowSourceBadge: Bool {
        #if DEBUG
        return !EnvironmentManager.shared.isProduction
        #else
        return false
        #endif
    }

    init(
        coverUrl: String?,
        dimensions: BookCoverDimensions,
        cornerRadius: CGFloat = 8,
        source: String? = nil
    ) {
        self.coverUrl = coverUrl
        self.dimensions = dimensions
        self.cornerRadius = cornerRadius
        self.source = source
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlString = coverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    KFImage(url)
                        .placeholder { _ in
                            ProgressView()
                                .frame(width: dimensions.width, height: dimensions.height)
                        }
                        .onFailure { _ in
                            // Failure handled by placeholder
                        }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: dimensions.width, height: dimensions.height)
                        .clipped()
                } else {
                    placeholder
                }
            }
            .frame(width: dimensions.width, height: dimensions.height)
            .cornerRadius(cornerRadius)

            #if DEBUG
            if shouldShowSourceBadge, let source = source, !source.isEmpty {
                SourceBadgeView(source: source)
                    .padding(4)
            }
            #endif
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.2))
            .frame(width: dimensions.width, height: dimensions.height)
            .overlay(
                Image(systemName: "book.fill")
                    .font(.system(size: dimensions.width * 0.25))
                    .foregroundColor(.gray.opacity(0.5))
            )
    }
}

/// Book cover with gradient placeholder based on genre
/// Uses Kingfisher for image caching (memory + disk)
struct GradientBookCoverView: View {
    let coverUrl: String?
    let dimensions: BookCoverDimensions
    let genre: String?
    let cornerRadius: CGFloat
    let source: String?

    /// Show source badge in all non-production environments
    private var shouldShowSourceBadge: Bool {
        #if DEBUG
        return !EnvironmentManager.shared.isProduction
        #else
        return false
        #endif
    }

    init(
        coverUrl: String?,
        dimensions: BookCoverDimensions,
        genre: String? = nil,
        cornerRadius: CGFloat = 8,
        source: String? = nil
    ) {
        self.coverUrl = coverUrl
        self.dimensions = dimensions
        self.genre = genre
        self.cornerRadius = cornerRadius
        self.source = source
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let urlString = coverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
                    KFImage(url)
                        .placeholder { _ in
                            ProgressView()
                                .frame(width: dimensions.width, height: dimensions.height)
                        }
                        .onFailure { _ in
                            // Show gradient placeholder on failure
                        }
                        .fade(duration: 0.25)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: dimensions.width, height: dimensions.height)
                        .clipped()
                } else {
                    gradientPlaceholder
                }
            }
            .frame(width: dimensions.width, height: dimensions.height)
            .cornerRadius(cornerRadius)

            #if DEBUG
            if shouldShowSourceBadge, let source = source, !source.isEmpty {
                SourceBadgeView(source: source)
                    .padding(4)
            }
            #endif
        }
    }

    private var gradientPlaceholder: some View {
        LinearGradient(
            colors: genreGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: dimensions.width, height: dimensions.height)
        .overlay(
            Image(systemName: "book.fill")
                .font(.system(size: dimensions.width * 0.3))
                .foregroundColor(.white.opacity(0.6))
        )
    }

    private var genreGradientColors: [Color] {
        guard let genre = genre?.lowercased() else {
            return [.gray, .blue.opacity(0.7)]
        }

        switch genre {
        case let g where g.contains("fiction"):
            return [.blue, .purple]
        case let g where g.contains("classic"):
            return [Color(red: 0.85, green: 0.65, blue: 0.13), .brown]
        case let g where g.contains("romance"):
            return [.pink, .red]
        case let g where g.contains("mystery"):
            return [.gray, .black]
        case let g where g.contains("science"):
            return [.cyan, .blue]
        case let g where g.contains("fantasy"):
            return [.purple, .pink]
        case let g where g.contains("adventure"):
            return [.orange, .yellow]
        default:
            return [.gray, .blue.opacity(0.7)]
        }
    }
}

// MARK: - Source Badge (DEBUG only)

#if DEBUG
/// Badge displaying book source for debugging purposes
struct SourceBadgeView: View {
    let source: String

    private var displayText: String {
        let lowercased = source.lowercased()
        if lowercased.contains("gutenberg") {
            return "Gutenberg"
        } else if lowercased.contains("standard") {
            return "Standard"
        } else {
            // Use the source name as-is, truncated if too long
            return String(source.prefix(10))
        }
    }

    private var badgeColor: Color {
        let lowercased = source.lowercased()
        if lowercased.contains("gutenberg") {
            return .orange
        } else if lowercased.contains("standard") {
            return .green
        } else {
            return .gray
        }
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 8, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(badgeColor.opacity(0.9)))
    }
}
#endif
