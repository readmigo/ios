import SwiftUI
import SafariServices

/// Section displaying book context (creation background, historical context, themes)
struct BookContextSection: View {
    let bookId: String
    @State private var bookContext: BookContext?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var expandedSections: Set<String> = ["creation", "historical", "themes", "style"]
    @State private var showingSafari = false
    @State private var safariURL: URL?

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let context = bookContext, context.hasContent {
                contentView(context)
            }
            // Don't show anything if no context or error
        }
        .task {
            await loadBookContext()
        }
        .sheet(isPresented: $showingSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("bookContext.loading".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Content View

    private func contentView(_ context: BookContext) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "book.pages")
                    .foregroundColor(.accentColor)
                Text("bookContext.title".localized)
                    .font(.headline)
            }

            // Context Sections
            VStack(spacing: 12) {
                if let creationBackground = context.creationBackground {
                    contextCard(
                        id: "creation",
                        icon: "pencil.and.outline",
                        title: "bookContext.creationBackground".localized,
                        content: creationBackground
                    )
                }

                if let historicalContext = context.historicalContext {
                    contextCard(
                        id: "historical",
                        icon: "clock.arrow.circlepath",
                        title: "bookContext.historicalContext".localized,
                        content: historicalContext
                    )
                }

                if let themes = context.themes {
                    contextCard(
                        id: "themes",
                        icon: "lightbulb",
                        title: "bookContext.themes".localized,
                        content: themes
                    )
                }

                if let literaryStyle = context.literaryStyle {
                    contextCard(
                        id: "style",
                        icon: "text.book.closed",
                        title: "bookContext.literaryStyle".localized,
                        content: literaryStyle
                    )
                }
            }

            // Source Attribution
            if let sourceUrl = context.sourceUrl {
                sourceAttribution(url: sourceUrl, license: context.license)
            }
        }
    }

    // MARK: - Context Card

    private func contextCard(id: String, icon: String, title: String, content: String) -> some View {
        let isExpanded = expandedSections.contains(id)
        let shouldTruncate = content.count > 200

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedSections.remove(id)
                    } else {
                        expandedSections.insert(id)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 20)

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Spacer()

                    if shouldTruncate {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(isExpanded || !shouldTruncate ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)

            if shouldTruncate && !isExpanded {
                Text("common.readMore".localized)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Source Attribution

    private func sourceAttribution(url: String, license: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundColor(.secondary)

            if let sourceURL = URL(string: url) {
                Button {
                    safariURL = sourceURL
                    showingSafari = true
                } label: {
                    Text("bookContext.sourceWikipedia".localized)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            Text("•")
                .foregroundColor(.secondary)

            Text(license)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Load Data

    private func loadBookContext() async {
        isLoading = true
        loadError = nil

        do {
            let endpoint = APIEndpoints.bookContext(bookId)
            let context: BookContext? = try await APIClient.shared.request(endpoint: endpoint)
            await MainActor.run {
                self.bookContext = context
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
            // Silently fail - just don't show the section
            LoggingService.shared.debug(.books, "Failed to load book context: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        BookContextSection(bookId: "test-book-id")
            .padding()
    }
}
