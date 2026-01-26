import SwiftUI

struct VocabularyPreviewView: View {
    let vocabulary: [VocabularyWord]
    let isLoading: Bool
    let onStart: () -> Void
    let onSkip: () -> Void
    let onMarkMastered: (String) -> Void

    @State private var selectedWords: Set<String> = []
    @State private var showAllWords = false

    private var displayedVocabulary: [VocabularyWord] {
        showAllWords ? vocabulary : Array(vocabulary.prefix(10))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "book.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.yellow)

                Text("Vocabulary Preview")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Review these words before listening")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)
            .padding(.bottom, 24)

            // Word list
            if isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                Text("Loading vocabulary...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.top, 16)
                Spacer()
            } else if vocabulary.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.green)

                    Text("No new vocabulary!")
                        .font(.title3)
                        .foregroundColor(.white)

                    Text("You're ready to listen to this chapter")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(displayedVocabulary) { word in
                            VocabularyWordCard(
                                word: word,
                                isSelected: selectedWords.contains(word.word),
                                onTap: {
                                    if selectedWords.contains(word.word) {
                                        selectedWords.remove(word.word)
                                    } else {
                                        selectedWords.insert(word.word)
                                    }
                                },
                                onMarkMastered: {
                                    onMarkMastered(word.word)
                                    selectedWords.remove(word.word)
                                }
                            )
                        }

                        // Show more button
                        if vocabulary.count > 10 && !showAllWords {
                            Button {
                                withAnimation {
                                    showAllWords = true
                                }
                            } label: {
                                HStack {
                                    Text("Show \(vocabulary.count - 10) more words")
                                    Image(systemName: "chevron.down")
                                }
                                .font(.subheadline)
                                .foregroundColor(.yellow)
                                .padding()
                            }
                        }
                    }
                    .padding()
                }
            }

            // Bottom buttons
            VStack(spacing: 12) {
                // Mark selected as known
                if !selectedWords.isEmpty {
                    Button {
                        for word in selectedWords {
                            onMarkMastered(word)
                        }
                        selectedWords.removeAll()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("I know these \(selectedWords.count) words")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }

                // Start listening
                Button {
                    onStart()
                } label: {
                    HStack {
                        Image(systemName: "headphones")
                        Text("Start Listening")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Skip preview
                Button {
                    onSkip()
                } label: {
                    Text("Skip Preview")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
        }
        .background(Color.black)
    }
}

// MARK: - Vocabulary Word Card

struct VocabularyWordCard: View {
    let word: VocabularyWord
    let isSelected: Bool
    let onTap: () -> Void
    let onMarkMastered: () -> Void

    @State private var showDefinition = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .green : .gray)
                    .onTapGesture(perform: onTap)

                // Word
                VStack(alignment: .leading, spacing: 2) {
                    Text(word.word)
                        .font(.headline)
                        .foregroundColor(.white)

                    if let pronunciation = word.pronunciation {
                        Text(pronunciation)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Difficulty badge
                DifficultyBadge(difficulty: word.difficulty)

                // Expand button
                Button {
                    withAnimation {
                        showDefinition.toggle()
                    }
                } label: {
                    Image(systemName: showDefinition ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            // Definition (expanded)
            if showDefinition {
                if let definition = word.definition {
                    Text(definition)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.leading, 32)
                } else {
                    Text("Definition not available")
                        .font(.subheadline)
                        .foregroundColor(.gray.opacity(0.6))
                        .italic()
                        .padding(.leading, 32)
                }

                // Mark as known button
                Button {
                    onMarkMastered()
                } label: {
                    HStack {
                        Image(systemName: "checkmark")
                        Text("I know this word")
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Difficulty Badge

struct DifficultyBadge: View {
    let difficulty: WordDifficulty

    var body: some View {
        Text(difficulty.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .cornerRadius(8)
    }

    private var color: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }
}
