import Foundation
import SwiftUI

// MARK: - Timeline Event

struct TimelineEvent: Codable, Identifiable {
    let id: String
    let bookId: String
    let title: String
    let titleChinese: String?
    let description: String
    let type: EventType
    let arc: StoryArcType
    let significance: EventSignificance
    let chapterIndex: Int
    let chapterTitle: String
    let position: Double // 0-1 within chapter
    let involvedCharacters: [String] // Character IDs
    let involvedCharacterNames: [String]
    let causedBy: [String]? // Event IDs that led to this
    let leadsTo: [String]? // Event IDs this causes
    let quote: String?
    let emotionalTone: EmotionalTone
    let timestamp: String? // In-story time if applicable
    let location: String?
    let createdAt: Date
}

// MARK: - Event Type

enum EventType: String, Codable, CaseIterable {
    case plotPoint
    case characterIntroduction
    case characterDeath
    case revelation
    case conflict
    case resolution
    case turningPoint
    case climax
    case setup
    case payoff
    case flashback
    case foreshadowing

    var displayName: String {
        switch self {
        case .plotPoint: return "Plot Point"
        case .characterIntroduction: return "Introduction"
        case .characterDeath: return "Death"
        case .revelation: return "Revelation"
        case .conflict: return "Conflict"
        case .resolution: return "Resolution"
        case .turningPoint: return "Turning Point"
        case .climax: return "Climax"
        case .setup: return "Setup"
        case .payoff: return "Payoff"
        case .flashback: return "Flashback"
        case .foreshadowing: return "Foreshadowing"
        }
    }

    var icon: String {
        switch self {
        case .plotPoint: return "circle.fill"
        case .characterIntroduction: return "person.badge.plus"
        case .characterDeath: return "person.badge.minus"
        case .revelation: return "lightbulb.fill"
        case .conflict: return "bolt.fill"
        case .resolution: return "checkmark.circle.fill"
        case .turningPoint: return "arrow.triangle.turn.up.right.circle.fill"
        case .climax: return "star.fill"
        case .setup: return "puzzlepiece"
        case .payoff: return "puzzlepiece.fill"
        case .flashback: return "clock.arrow.circlepath"
        case .foreshadowing: return "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .plotPoint: return .blue
        case .characterIntroduction: return .green
        case .characterDeath: return .black
        case .revelation: return .yellow
        case .conflict: return .red
        case .resolution: return .green
        case .turningPoint: return .purple
        case .climax: return .orange
        case .setup: return .gray
        case .payoff: return .teal
        case .flashback: return .brown
        case .foreshadowing: return .indigo
        }
    }
}

// MARK: - Story Arc Type

enum StoryArcType: String, Codable, CaseIterable {
    case exposition
    case risingAction
    case climax
    case fallingAction
    case resolution
    case denouement

    var displayName: String {
        switch self {
        case .exposition: return "Exposition"
        case .risingAction: return "Rising Action"
        case .climax: return "Climax"
        case .fallingAction: return "Falling Action"
        case .resolution: return "Resolution"
        case .denouement: return "Denouement"
        }
    }

    var chineseName: String {
        switch self {
        case .exposition: return "开端"
        case .risingAction: return "发展"
        case .climax: return "高潮"
        case .fallingAction: return "转折"
        case .resolution: return "结局"
        case .denouement: return "尾声"
        }
    }

    var color: Color {
        switch self {
        case .exposition: return .blue
        case .risingAction: return .orange
        case .climax: return .red
        case .fallingAction: return .purple
        case .resolution: return .green
        case .denouement: return .gray
        }
    }

    var order: Int {
        switch self {
        case .exposition: return 0
        case .risingAction: return 1
        case .climax: return 2
        case .fallingAction: return 3
        case .resolution: return 4
        case .denouement: return 5
        }
    }
}

// MARK: - Event Significance

enum EventSignificance: String, Codable, CaseIterable {
    case critical // Major plot event
    case major // Important event
    case moderate // Notable event
    case minor // Background event

    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .major: return "Major"
        case .moderate: return "Moderate"
        case .minor: return "Minor"
        }
    }

    var size: CGFloat {
        switch self {
        case .critical: return 24
        case .major: return 18
        case .moderate: return 14
        case .minor: return 10
        }
    }

    var weight: Int {
        switch self {
        case .critical: return 4
        case .major: return 3
        case .moderate: return 2
        case .minor: return 1
        }
    }
}

// MARK: - Emotional Tone

enum EmotionalTone: String, Codable, CaseIterable {
    case joyful
    case hopeful
    case tense
    case sad
    case angry
    case fearful
    case surprising
    case romantic
    case mysterious
    case neutral

    var displayName: String {
        switch self {
        case .joyful: return "Joyful"
        case .hopeful: return "Hopeful"
        case .tense: return "Tense"
        case .sad: return "Sad"
        case .angry: return "Angry"
        case .fearful: return "Fearful"
        case .surprising: return "Surprising"
        case .romantic: return "Romantic"
        case .mysterious: return "Mysterious"
        case .neutral: return "Neutral"
        }
    }

    var emoji: String {
        switch self {
        case .joyful: return "😊"
        case .hopeful: return "🌟"
        case .tense: return "😰"
        case .sad: return "😢"
        case .angry: return "😠"
        case .fearful: return "😨"
        case .surprising: return "😮"
        case .romantic: return "💕"
        case .mysterious: return "🔮"
        case .neutral: return "😐"
        }
    }

    var color: Color {
        switch self {
        case .joyful: return .yellow
        case .hopeful: return .green
        case .tense: return .orange
        case .sad: return .blue
        case .angry: return .red
        case .fearful: return .purple
        case .surprising: return .pink
        case .romantic: return .pink
        case .mysterious: return .indigo
        case .neutral: return .gray
        }
    }
}

// MARK: - Story Arc

struct StoryArc: Codable, Identifiable {
    let id: String
    let bookId: String
    let type: StoryArcType
    let startChapter: Int
    let endChapter: Int
    let events: [String] // Event IDs
    let summary: String
    let tensionLevel: Double // 0-1

    var chapterRange: String {
        if startChapter == endChapter {
            return "Chapter \(startChapter + 1)"
        }
        return "Chapters \(startChapter + 1)-\(endChapter + 1)"
    }
}

// MARK: - Timeline Response

struct TimelineResponse: Codable {
    let bookId: String
    let events: [TimelineEvent]
    let arcs: [StoryArc]
    let analyzedChapters: Int
    let totalChapters: Int
    let lastAnalyzedAt: Date
}

// MARK: - Timeline Analysis Request

struct TimelineAnalysisRequest: Codable {
    let bookId: String
    let forceReanalyze: Bool
    let detailLevel: TimelineDetailLevel
}

enum TimelineDetailLevel: String, Codable {
    case summary // Only major events
    case standard // Major + moderate events
    case detailed // All events
}

// MARK: - Chapter Summary

struct ChapterSummary: Codable, Identifiable {
    let id: String
    let bookId: String
    let chapterIndex: Int
    let chapterTitle: String
    let summary: String
    let summaryChinese: String?
    let keyEvents: [String] // Event IDs
    let charactersIntroduced: [String] // Character IDs
    let emotionalArc: [EmotionalTone]
    let tensionLevel: Double
    let wordCount: Int
    let estimatedReadTime: Int // minutes
}

// MARK: - Plot Thread

struct PlotThread: Codable, Identifiable {
    let id: String
    let bookId: String
    let name: String
    let description: String
    let status: PlotThreadStatus
    let events: [String] // Event IDs in order
    let characters: [String] // Character IDs involved
    let startChapter: Int
    let endChapter: Int?
    let isMainPlot: Bool

    enum PlotThreadStatus: String, Codable {
        case introduced
        case developing
        case climaxing
        case resolved
        case abandoned

        var color: Color {
            switch self {
            case .introduced: return .blue
            case .developing: return .orange
            case .climaxing: return .red
            case .resolved: return .green
            case .abandoned: return .gray
            }
        }
    }
}

// MARK: - Timeline Filter

struct TimelineFilter {
    var eventTypes: Set<EventType> = Set(EventType.allCases)
    var arcs: Set<StoryArcType> = Set(StoryArcType.allCases)
    var minSignificance: EventSignificance = .minor
    var characters: Set<String> = []
    var chapterRange: ClosedRange<Int>?

    var isDefault: Bool {
        eventTypes.count == EventType.allCases.count &&
        arcs.count == StoryArcType.allCases.count &&
        minSignificance == .minor &&
        characters.isEmpty &&
        chapterRange == nil
    }

    func matches(_ event: TimelineEvent) -> Bool {
        guard eventTypes.contains(event.type) else { return false }
        guard arcs.contains(event.arc) else { return false }
        guard event.significance.weight >= minSignificance.weight else { return false }

        if !characters.isEmpty {
            let eventChars = Set(event.involvedCharacters)
            guard !characters.isDisjoint(with: eventChars) else { return false }
        }

        if let range = chapterRange {
            guard range.contains(event.chapterIndex) else { return false }
        }

        return true
    }
}
