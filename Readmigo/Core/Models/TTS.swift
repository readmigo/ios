import Foundation
import AVFoundation

// MARK: - TTS Settings

struct TTSSettings: Codable {
    var rate: Float // 0.0 - 1.0 (mapped to AVSpeechUtteranceMinimumSpeechRate to Maximum)
    var pitch: Float // 0.5 - 2.0
    var volume: Float // 0.0 - 1.0
    var voiceIdentifier: String?
    var language: String
    var highlightMode: TTSHighlightMode
    var autoScroll: Bool
    var autoPageTurn: Bool
    var sleepTimerMinutes: Int?
    var readingMode: TTSReadingMode
    var pauseBetweenSentences: Double
    var pauseBetweenParagraphs: Double

    static var `default`: TTSSettings {
        TTSSettings(
            rate: 0.5,
            pitch: 1.0,
            volume: 1.0,
            voiceIdentifier: nil,
            language: "en-US",
            highlightMode: .sentence,
            autoScroll: true,
            autoPageTurn: true,
            sleepTimerMinutes: nil,
            readingMode: .continuous,
            pauseBetweenSentences: 0.3,
            pauseBetweenParagraphs: 0.8
        )
    }

    var displayRate: String {
        let speed = rate * 2 // Convert to 0-2x range display
        return String(format: "%.1fx", speed)
    }

    var actualRate: Float {
        AVSpeechUtteranceMinimumSpeechRate + rate * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
    }
}

// MARK: - TTS Highlight Mode

enum TTSHighlightMode: String, Codable, CaseIterable {
    case none
    case word
    case sentence
    case paragraph

    var displayName: String {
        switch self {
        case .none: return "None"
        case .word: return "Word"
        case .sentence: return "Sentence"
        case .paragraph: return "Paragraph"
        }
    }

    var description: String {
        switch self {
        case .none: return "No highlighting"
        case .word: return "Highlight each word"
        case .sentence: return "Highlight current sentence"
        case .paragraph: return "Highlight current paragraph"
        }
    }
}

// MARK: - TTS Reading Mode

enum TTSReadingMode: String, Codable, CaseIterable {
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

    var description: String {
        switch self {
        case .continuous: return "Read through entire book"
        case .chapter: return "Stop at chapter end"
        case .selection: return "Read selected text only"
        }
    }
}

// MARK: - TTS State

enum TTSState {
    case idle
    case playing
    case paused
    case loading

    var icon: String {
        switch self {
        case .idle, .paused: return "play.fill"
        case .playing: return "pause.fill"
        case .loading: return "ellipsis"
        }
    }
}

// MARK: - TTS Voice

struct TTSVoice: Identifiable {
    let id: String
    let name: String
    let language: String
    let quality: VoiceQuality
    let gender: VoiceGender?
    let isDefault: Bool

    enum VoiceQuality: String {
        case `default`
        case enhanced
        case premium

        var displayName: String {
            switch self {
            case .default: return "Standard"
            case .enhanced: return "Enhanced"
            case .premium: return "Premium"
            }
        }

        var badge: String? {
            switch self {
            case .default: return nil
            case .enhanced: return "HD"
            case .premium: return "Premium"
            }
        }
    }

    enum VoiceGender: String {
        case male
        case female
        case neutral

        var icon: String {
            switch self {
            case .male: return "person.fill"
            case .female: return "person.fill"
            case .neutral: return "person.fill"
            }
        }
    }

    static func fromAVVoice(_ voice: AVSpeechSynthesisVoice) -> TTSVoice {
        let quality: VoiceQuality
        switch voice.quality {
        case .enhanced:
            quality = .enhanced
        case .premium:
            quality = .premium
        default:
            quality = .default
        }

        return TTSVoice(
            id: voice.identifier,
            name: voice.name,
            language: voice.language,
            quality: quality,
            gender: voice.gender == .male ? .male : voice.gender == .female ? .female : .neutral,
            isDefault: false
        )
    }
}

// MARK: - TTS Utterance Info

struct TTSUtteranceInfo {
    let text: String
    let chapterId: String
    let paragraphIndex: Int
    let sentenceIndex: Int
    let wordRange: NSRange?
    let startPosition: Int
    let endPosition: Int
}

// MARK: - Sleep Timer Option

enum SleepTimerOption: Int, CaseIterable {
    case off = 0
    case minutes5 = 5
    case minutes10 = 10
    case minutes15 = 15
    case minutes30 = 30
    case minutes45 = 45
    case hour1 = 60
    case endOfChapter = -1

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .minutes5: return "5 minutes"
        case .minutes10: return "10 minutes"
        case .minutes15: return "15 minutes"
        case .minutes30: return "30 minutes"
        case .minutes45: return "45 minutes"
        case .hour1: return "1 hour"
        case .endOfChapter: return "End of chapter"
        }
    }
}

// MARK: - Pronunciation Guide

struct PronunciationEntry: Codable, Identifiable {
    let id: String
    let word: String
    let pronunciation: String // IPA or phonetic spelling
    let audioUrl: String?
    let language: String

    init(word: String, pronunciation: String, audioUrl: String? = nil, language: String = "en") {
        self.id = UUID().uuidString
        self.word = word
        self.pronunciation = pronunciation
        self.audioUrl = audioUrl
        self.language = language
    }
}

// MARK: - TTS Progress

struct TTSProgress {
    let currentWord: String?
    let currentSentence: String?
    let currentParagraph: Int
    let totalParagraphs: Int
    let characterOffset: Int
    let totalCharacters: Int

    var progressPercentage: Double {
        guard totalCharacters > 0 else { return 0 }
        return Double(characterOffset) / Double(totalCharacters)
    }

    var timeRemaining: TimeInterval? {
        // Estimate based on average reading speed
        let remainingChars = totalCharacters - characterOffset
        let charsPerSecond: Double = 15 // Average TTS speed
        return Double(remainingChars) / charsPerSecond
    }

    var formattedTimeRemaining: String? {
        guard let time = timeRemaining else { return nil }
        let minutes = Int(time / 60)
        if minutes < 1 {
            return "< 1 min"
        } else if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        }
    }
}
