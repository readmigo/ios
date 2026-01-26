import SwiftUI

struct ReviewSessionView: View {
    @StateObject private var manager = VocabularyManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var currentIndex = 0
    @State private var showAnswer = false
    @State private var isSubmitting = false
    @State private var completedCount = 0

    var body: some View {
        NavigationStack {
            VStack {
                // Progress Header
                ProgressHeader(
                    current: currentIndex + 1,
                    total: manager.reviewWords.count,
                    completed: completedCount
                )

                if manager.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if manager.reviewWords.isEmpty {
                    ReviewCompleteView(completedCount: completedCount) {
                        dismiss()
                    }
                } else if currentIndex < manager.reviewWords.count {
                    // Current Card
                    FlashcardView(
                        word: manager.reviewWords[currentIndex],
                        showAnswer: showAnswer,
                        onShowAnswer: {
                            withAnimation(.spring()) {
                                showAnswer = true
                            }
                        }
                    )

                    // Answer Buttons
                    if showAnswer {
                        AnswerButtons(
                            isSubmitting: isSubmitting,
                            onAnswer: { quality in
                                Task { await submitAnswer(quality: quality) }
                            }
                        )
                    }
                } else {
                    ReviewCompleteView(completedCount: completedCount) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("End") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await manager.fetchReviewWords()
        }
    }

    private func submitAnswer(quality: Int) async {
        guard currentIndex < manager.reviewWords.count else { return }

        isSubmitting = true
        let word = manager.reviewWords[currentIndex]

        do {
            try await manager.submitReview(wordId: word.id, quality: quality)
            completedCount += 1

            // Move to next card
            withAnimation {
                showAnswer = false
                currentIndex += 1
            }
        } catch {
            print("Failed to submit review: \(error)")
        }

        isSubmitting = false
    }
}

// MARK: - Progress Header

struct ProgressHeader: View {
    let current: Int
    let total: Int
    let completed: Int

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Card \(current) of \(total)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(completed) reviewed")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
            .padding(.horizontal)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * CGFloat(completed) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Flashcard

struct FlashcardView: View {
    let word: VocabularyWord
    let showAnswer: Bool
    let onShowAnswer: () -> Void

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 20) {
                // Word
                Text(word.word)
                    .font(.system(size: 36, weight: .bold))
                    .multilineTextAlignment(.center)

                // Context
                Text(word.context)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if showAnswer {
                    Divider()
                        .padding(.vertical, 10)

                    // Answer Section
                    VStack(spacing: 12) {
                        if let notes = word.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.title3)
                                .multilineTextAlignment(.center)
                        } else {
                            Text("(No definition saved)")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(30)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 20)

            Spacer()

            if !showAnswer {
                Button(action: onShowAnswer) {
                    Text("Show Answer")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Answer Buttons

struct AnswerButtons: View {
    let isSubmitting: Bool
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("How well did you remember?")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                AnswerButton(
                    label: "Again",
                    subtitle: "< 1 min",
                    color: .red,
                    isSubmitting: isSubmitting
                ) {
                    onAnswer(0)
                }

                AnswerButton(
                    label: "Hard",
                    subtitle: "1 day",
                    color: .orange,
                    isSubmitting: isSubmitting
                ) {
                    onAnswer(2)
                }

                AnswerButton(
                    label: "Good",
                    subtitle: "3 days",
                    color: .blue,
                    isSubmitting: isSubmitting
                ) {
                    onAnswer(3)
                }

                AnswerButton(
                    label: "Easy",
                    subtitle: "7 days",
                    color: .green,
                    isSubmitting: isSubmitting
                ) {
                    onAnswer(5)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 30)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct AnswerButton: View {
    let label: String
    let subtitle: String
    let color: Color
    let isSubmitting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(subtitle)
                    .font(.caption2)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .disabled(isSubmitting)
        .opacity(isSubmitting ? 0.6 : 1)
    }
}

// MARK: - Review Complete

struct ReviewCompleteView: View {
    let completedCount: Int
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("Review Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("You reviewed \(completedCount) words")
                .font(.title3)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }
}
