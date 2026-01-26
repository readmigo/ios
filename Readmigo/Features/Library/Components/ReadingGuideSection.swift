import SwiftUI

/// Section displaying reading guide (阅读指南) for cross-cultural readers
struct ReadingGuideSection: View {
    let bookId: String
    @State private var readingGuide: ReadingGuide?
    @State private var isLoading = true
    @State private var loadError: Error?
    @State private var expandedSections: Set<String> = ["warnings", "timeline", "quickstart"]

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let guide = readingGuide, guide.hasContent {
                contentView(guide)
            }
            // Don't show anything if no guide or error
        }
        .task {
            await loadReadingGuide()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("readingGuide.loading".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Content View

    private func contentView(_ guide: ReadingGuide) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "book.and.wrench")
                    .foregroundColor(.accentColor)
                Text("readingGuide.title".localized)
                    .font(.headline)
            }

            // Guide Sections
            VStack(spacing: 12) {
                if let readingWarnings = guide.readingWarnings {
                    guideCard(
                        id: "warnings",
                        icon: "exclamationmark.triangle",
                        title: "readingGuide.warnings".localized,
                        content: readingWarnings
                    )
                }

                if let storyTimeline = guide.storyTimeline {
                    guideCard(
                        id: "timeline",
                        icon: "text.book.closed",
                        title: "readingGuide.storyTimeline".localized,
                        content: storyTimeline
                    )
                }

                if let quickStartGuide = guide.quickStartGuide {
                    guideCard(
                        id: "quickstart",
                        icon: "bolt.fill",
                        title: "readingGuide.quickStart".localized,
                        content: quickStartGuide
                    )
                }
            }

            // AI Attribution
            if guide.sourceType == "AI_GENERATED" {
                aiAttribution(aiModel: guide.aiModel)
            }
        }
    }

    // MARK: - Guide Card

    private func guideCard(id: String, icon: String, title: String, content: String) -> some View {
        let isExpanded = expandedSections.contains(id)

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

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - AI Attribution

    private func aiAttribution(aiModel: String?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundColor(.secondary)

            Text("readingGuide.aiGenerated".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Load Data

    private func loadReadingGuide() async {
        isLoading = true
        loadError = nil

        do {
            let endpoint = APIEndpoints.bookReadingGuide(bookId)
            let guide: ReadingGuide? = try await APIClient.shared.request(endpoint: endpoint)
            await MainActor.run {
                self.readingGuide = guide
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.loadError = error
                self.isLoading = false
            }
            // Silently fail - just don't show the section
            LoggingService.shared.debug(.books, "Failed to load reading guide: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        ReadingGuideSection(bookId: "test-book-id")
            .padding()
    }
}
