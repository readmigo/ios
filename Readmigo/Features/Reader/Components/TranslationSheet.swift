import SwiftUI

/// Sheet for displaying paragraph translation
struct TranslationSheet: View {
    let bookId: String
    let chapterId: String
    let paragraphIndex: Int
    let originalText: String
    let onDismiss: () -> Void

    @StateObject private var translationService = TranslationService.shared
    @State private var translation: ParagraphTranslation?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 16)

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding()
                            Spacer()
                        }
                    } else if let errorMessage = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if let translation = translation {
                        Text(translation.translation)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .task {
            await loadTranslation()
        }
    }

    // MARK: - Load Translation

    private func loadTranslation() async {
        isLoading = true
        errorMessage = nil

        // Check if translation is needed
        guard translationService.needsTranslation else {
            errorMessage = "translation.notNeeded".localized
            isLoading = false
            return
        }

        do {
            translation = try await translationService.getTranslation(
                bookId: bookId,
                chapterId: chapterId,
                paragraphIndex: paragraphIndex
            )
            isLoading = false
        } catch let error as TranslationError {
            isLoading = false
            switch error {
            case .notAvailable:
                errorMessage = "translation.error.notAvailable".localized
            case .unsupportedLocale:
                errorMessage = "translation.error.unsupportedLocale".localized
            case .networkError:
                errorMessage = "translation.error.network".localized
            case .unknown:
                errorMessage = "translation.error.unknown".localized
            }
        } catch {
            isLoading = false
            errorMessage = "translation.error.unknown".localized
        }
    }

    // MARK: - Helpers

    private func localeName(for locale: String) -> String {
        switch locale {
        case "zh-Hans": return "Chinese (Simplified)"
        case "zh-Hant": return "Chinese (Traditional)"
        case "es": return "Spanish"
        case "hi": return "Hindi"
        case "ar": return "Arabic"
        case "pt": return "Portuguese"
        case "ja": return "Japanese"
        case "ko": return "Korean"
        case "fr": return "French"
        case "de": return "German"
        default: return locale
        }
    }
}
