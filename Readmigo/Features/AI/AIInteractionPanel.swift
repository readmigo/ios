import SwiftUI

struct AIInteractionPanel: View {
    let selectedText: String
    let sentence: String
    let bookId: String?
    let chapterId: String?
    let onDismiss: () -> Void

    @EnvironmentObject var authManager: AuthManager
    @State private var selectedAction: AIAction = .explain
    @State private var response: String?
    @State private var responseFromCache = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var showAddToVocabulary = false
    @State private var showLoginPrompt = false

    private let aiService = AIService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Drag Handle
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            // Header
            HStack {
                Text(selectedText)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            // Action Buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AIAction.allCases, id: \.self) { action in
                        ActionButton(
                            action: action,
                            isSelected: selectedAction == action
                        ) {
                            selectedAction = action
                            Task { await performAction() }
                        }
                    }
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.vertical, 12)

            // Response Area
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoading {
                        VStack(spacing: 12) {
                            ShimmerLoadingView()
                            HStack {
                                TypingIndicator()
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                    } else if let error = error {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Retry") {
                                Task { await performAction() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if let response = response {
                        TypewriterTextView(
                            fullText: response,
                            fromCache: responseFromCache
                        )
                        .padding()
                    } else {
                        Text("Select an action to get AI assistance")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }

            // Bottom Actions
            if selectedAction == .explain && response != nil {
                Divider()

                HStack {
                    Button {
                        // Check login for vocabulary
                        guard requireLoginForVocabulary() else { return }
                        showAddToVocabulary = true
                    } label: {
                        Label("Add to Vocabulary", systemImage: "plus.circle")
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        copyToClipboard()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: -5)
        .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
        .offset(y: UIScreen.main.bounds.height * 0.25)
        .sheet(isPresented: $showAddToVocabulary) {
            AddVocabularyView(
                word: selectedText,
                sentence: sentence,
                bookId: bookId
            )
        }
        .task {
            await performAction()
        }
        .loginPrompt(isPresented: $showLoginPrompt, feature: "vocabulary")
    }

    // MARK: - Guest Mode Helpers

    private func requireLoginForVocabulary() -> Bool {
        if authManager.isAuthenticated {
            return true
        } else {
            showLoginPrompt = true
            return false
        }
    }

    private func performAction() async {
        isLoading = true
        error = nil
        response = nil
        responseFromCache = false

        do {
            let result: AIResponse

            switch selectedAction {
            case .explain:
                result = try await aiService.explainWord(
                    word: selectedText,
                    sentence: sentence,
                    bookId: bookId,
                    chapterId: chapterId
                )

            case .simplify:
                result = try await aiService.simplifySentence(
                    sentence: sentence,
                    bookId: bookId
                )

            case .translate:
                result = try await aiService.translateParagraph(
                    paragraph: sentence,
                    bookId: bookId
                )

            case .analyze:
                // Q&A is not cached
                result = try await aiService.askQuestion(
                    question: "Analyze the meaning and context of this passage",
                    context: sentence,
                    bookTitle: nil,
                    bookId: bookId
                )
            }

            response = result.content
            responseFromCache = result.isCached

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = response
    }
}

// MARK: - AI Actions

enum AIAction: String, CaseIterable {
    case explain = "Explain"
    case simplify = "Simplify"
    case translate = "Translate"
    case analyze = "Analyze"

    var icon: String {
        switch self {
        case .explain: return "lightbulb"
        case .simplify: return "text.justify.left"
        case .translate: return "globe"
        case .analyze: return "magnifyingglass"
        }
    }

    var description: String {
        switch self {
        case .explain: return "Get word definition and usage"
        case .simplify: return "Simplify the sentence"
        case .translate: return "Translate to Chinese"
        case .analyze: return "Analyze the context"
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let action: AIAction
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.title3)

                Text(action.rawValue)
                    .font(.caption)
            }
            .frame(width: 70, height: 60)
            .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(12)
        }
    }
}


// MARK: - Add Vocabulary View

struct AddVocabularyView: View {
    let word: String
    let sentence: String
    let bookId: String?

    @Environment(\.dismiss) private var dismiss
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    Text(word)
                        .font(.headline)
                }

                Section("Context") {
                    Text(sentence)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Notes (Optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Add to Vocabulary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveWord() }
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
        }
    }

    private func saveWord() async {
        isLoading = true

        do {
            let request = AIAddVocabRequest(
                word: word,
                context: sentence,
                bookId: bookId,
                notes: notes.isEmpty ? nil : notes
            )

            let _: VocabularyWord = try await APIClient.shared.request(
                endpoint: APIEndpoints.vocabulary,
                method: .post,
                body: request
            )

            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

private struct AIAddVocabRequest: Codable {
    let word: String
    let context: String
    let bookId: String?
    let notes: String?
}
