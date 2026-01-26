import SwiftUI
import Kingfisher

// MARK: - Immersive Header for Book Detail

/// A full-height immersive header with book cover and gradient overlays
/// Designed to work with ImmersiveNavigationBar for scroll-driven effects
struct BookDetailHeaderImmersive: View {
    let book: Book
    var scrollOffset: CGFloat = 0

    // Appear animation state
    @State private var hasAppeared = false

    // Fixed dimensions
    private let coverWidth: CGFloat = 160
    private let coverHeight: CGFloat = 240
    private let navBarHeight: CGFloat = 44
    private let topPadding: CGFloat = 8
    private let coverTitleSpacing: CGFloat = 16
    private let bottomPadding: CGFloat = 40

    // Calculate total header height
    private var headerHeight: CGFloat {
        safeAreaTop + navBarHeight + topPadding + coverHeight + coverTitleSpacing + estimatedTitleHeight + bottomPadding
    }

    // Estimate title area height (title + word count)
    private var estimatedTitleHeight: CGFloat {
        70 // Approximate height for title (up to 3 lines) + word count label
    }

    // MARK: - Scroll-based Animation Values

    // Parallax offset for cover (moves slower than scroll)
    private var parallaxOffset: CGFloat {
        scrollOffset > 0 ? scrollOffset * 0.3 : 0
    }

    // Scale effect for cover (shrinks slightly on scroll)
    private var coverScale: CGFloat {
        let scale = 1.0 - (scrollOffset / 800)
        return max(0.85, min(1.0, scale))
    }

    // Opacity for content (fades on scroll)
    private var contentOpacity: Double {
        let opacity = 1.0 - (Double(scrollOffset) / 300)
        return max(0.0, min(1.0, opacity))
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Dark base layer to prevent white blur edges
            Color.black
                .frame(maxWidth: .infinity)
                .frame(height: headerHeight)

            // Background blur layer
            bookCoverBackground
                .frame(maxWidth: .infinity)
                .frame(height: headerHeight)
                .clipped()
                .blur(radius: 30)
                .overlay(Color.black.opacity(0.3))

            // Gradient overlays
            VStack(spacing: 0) {
                // Top dark gradient (ensures back button visibility)
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.6),
                        Color.black.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 100)

                Spacer()

                // Bottom gradient (transition to content area)
                LinearGradient(
                    colors: [Color.clear, Color(.systemBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
            }
            .frame(height: headerHeight)

            // Cover + Title content with animations
            VStack(spacing: coverTitleSpacing) {
                // Book cover with parallax, scale and appear animation
                bookCoverView
                    .frame(width: coverWidth, height: coverHeight)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .scaleEffect(hasAppeared ? coverScale : 0.8)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: parallaxOffset)

                // Title and metadata with staggered appear animation
                VStack(spacing: 8) {
                    Text(book.localizedTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.8), radius: 4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 20)

                    if let wordCount = book.wordCount {
                        Label(
                            String(format: "book.wordsK".localized, wordCount / 1000),
                            systemImage: "doc.text"
                        )
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.8), radius: 4)
                        .opacity(hasAppeared ? 1 : 0)
                        .offset(y: hasAppeared ? 0 : 15)
                    }
                }
                .offset(y: parallaxOffset * 0.5)
            }
            .padding(.top, safeAreaTop + navBarHeight + topPadding)
            .opacity(contentOpacity)
        }
        .frame(maxWidth: .infinity)
        .frame(height: headerHeight)
        .clipped()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Private Views

    @ViewBuilder
    private var bookCoverBackground: some View {
        if let urlString = book.coverUrl, !urlString.isEmpty, let url = URL(string: urlString) {
            KFImage(url)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.gray.opacity(0.3)
        }
    }

    @ViewBuilder
    private var bookCoverView: some View {
        Color.clear
            .aspectRatio(2/3, contentMode: .fit)
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
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
}
