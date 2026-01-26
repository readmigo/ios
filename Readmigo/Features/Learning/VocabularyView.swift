import SwiftUI

struct VocabularyView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var manager = VocabularyManager.shared
    @State private var searchText = ""
    @State private var showingReview = false
    @State private var selectedWord: VocabularyWord?

    var body: some View {
        NavigationStack {
            if !authManager.isAuthenticated {
                LoginRequiredView(feature: "vocabulary")
            } else {
            VStack(spacing: 0) {
                // Stats Header
                if let stats = manager.stats {
                    StatsHeader(stats: stats) {
                        showingReview = true
                    }
                }

                // Search Bar
                SearchBar(text: $searchText, onSearch: {})
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // Word List
                if manager.isLoading && manager.words.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredWords.isEmpty {
                    EmptyVocabularyView()
                } else {
                    List {
                        ForEach(filteredWords) { word in
                            WordRow(word: word)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedWord = word
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task {
                                            try? await manager.deleteWord(id: word.id)
                                        }
                                    } label: {
                                        Label("common.delete".localized, systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("nav.vocabulary".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingReview = true
                    } label: {
                        Image(systemName: "brain.head.profile")
                    }
                    .disabled(manager.reviewWords.isEmpty)
                }
            }
            .sheet(item: $selectedWord) { word in
                WordDetailView(word: word)
            }
            .fullScreenCover(isPresented: $showingReview) {
                ReviewSessionView()
            }
            }
        }
        .task {
            await manager.fetchVocabulary()
            await manager.fetchStats()
            await manager.fetchReviewWords()
        }
    }

    private var filteredWords: [VocabularyWord] {
        if searchText.isEmpty {
            return manager.words
        }
        return manager.words.filter {
            $0.word.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Stats Header

private struct StatsHeader: View {
    let stats: VocabularyStats
    let onReviewTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                StatItem(value: stats.totalWords, label: "vocabulary.total".localized, color: .blue)
                StatItem(value: stats.masteredWords, label: "vocabulary.mastered".localized, color: .green)
                StatItem(value: stats.learningWords, label: "vocabulary.learning".localized, color: .orange)
            }

            if stats.dueForReview > 0 {
                Button(action: onReviewTap) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                        Text("vocabulary.dueForReview".localized(with: stats.dueForReview))
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
    }
}

private struct StatItem: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Word Row

struct WordRow: View {
    let word: VocabularyWord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(word.word)
                    .font(.headline)

                Text(word.context)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Mastery indicator
            MasteryBadge(repetitions: word.repetitions)
        }
        .padding(.vertical, 4)
    }
}

struct MasteryBadge: View {
    let repetitions: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < min(repetitions, 5) ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Empty State

struct EmptyVocabularyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("vocabulary.empty.title".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text("vocabulary.empty.hint".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Word Detail

struct WordDetailView: View {
    let word: VocabularyWord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Word Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(word.word)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        MasteryBadge(repetitions: word.repetitions)
                    }

                    Divider()

                    // Context
                    VStack(alignment: .leading, spacing: 8) {
                        Text("vocabulary.context".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text(word.context)
                            .font(.body)
                            .italic()
                    }

                    // Notes
                    if let notes = word.notes {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("vocabulary.notes".localized)
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text(notes)
                                .font(.body)
                        }
                    }

                    // Review Stats
                    VStack(alignment: .leading, spacing: 8) {
                        Text("vocabulary.reviewStats".localized)
                            .font(.headline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 20) {
                            StatBlock(label: "vocabulary.reviews".localized, value: "\(word.repetitions)")
                            StatBlock(label: "vocabulary.interval".localized, value: "vocabulary.intervalDays".localized(with: word.interval))
                            StatBlock(label: "vocabulary.ease".localized, value: String(format: "%.1f", word.easeFactor))
                        }
                    }

                    // Next Review
                    if let nextReview = word.nextReviewAt {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("vocabulary.nextReview".localized)
                                .font(.headline)
                                .foregroundColor(.secondary)

                            Text(nextReview, style: .date)
                                .font(.body)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("vocabulary.wordDetails".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct StatBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
