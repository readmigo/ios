import Foundation

// MARK: - Chapter Text API Response

struct ChapterTextResponse: Decodable {
    let chapterId: String
    let title: String
    let paragraphs: [ChapterParagraph]
}

struct ChapterParagraph: Identifiable {
    let index: Int
    let text: String

    var id: Int { index }
}

extension ChapterParagraph: Decodable {}
extension ChapterParagraph: Encodable {}

// MARK: - Read Aloud State

enum ReadAloudState: Equatable {
    case idle
    case loading
    case playing
    case paused
    case loadingNextChapter

    var isActive: Bool {
        switch self {
        case .playing, .paused, .loadingNextChapter:
            return true
        case .idle, .loading:
            return false
        }
    }
}

// MARK: - Read Aloud Position

struct ReadAloudPosition: Codable {
    let bookId: String
    let chapterId: String
    let paragraphIndex: Int
    let sentenceIndex: Int
}

// MARK: - Read Aloud Progress

struct ReadAloudProgress {
    let currentParagraphIndex: Int
    let totalParagraphs: Int
    let currentSentenceInParagraph: Int
    let totalSentencesInParagraph: Int
    let globalSentenceIndex: Int
    let totalSentences: Int

    var chapterPercent: Double {
        guard totalSentences > 0 else { return 0 }
        return Double(globalSentenceIndex) / Double(totalSentences)
    }

    var estimatedTimeRemaining: TimeInterval {
        let remainingSentences = totalSentences - globalSentenceIndex
        // ~3 seconds per sentence at normal speed
        return Double(remainingSentences) * 3.0
    }

    var formattedTimeRemaining: String {
        let seconds = Int(estimatedTimeRemaining)
        let minutes = seconds / 60
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }
}

// MARK: - Read Aloud Mode

enum ReadAloudMode: String, Codable, CaseIterable {
    case continuous
    case chapter
    case selection

    var displayName: String {
        switch self {
        case .continuous: return "Continuous"
        case .chapter: return "Chapter"
        case .selection: return "Selection Only"
        }
    }
}
