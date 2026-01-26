import Foundation
import SwiftUI

// MARK: - Character

struct Character: Codable, Identifiable, Hashable {
    let id: String
    let bookId: String
    let name: String
    let nameChinese: String?
    let aliases: [String]
    let role: CharacterRole
    let shortDescription: String
    let fullDescription: String?
    let personality: [PersonalityTrait]
    let appearance: String?
    let background: String?
    let motivations: [String]
    let firstAppearanceChapter: Int
    let firstAppearanceText: String?
    let imageUrl: String?
    let aiGeneratedImage: String?
    let importanceScore: Double // 0-1, higher = more important
    let mentionCount: Int
    let relationships: [CharacterRelationship]
    let dataSource: CharacterDataSource?
    let wikidataQid: String?
    let createdAt: Date
    let updatedAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Character Role

enum CharacterRole: String, Codable, CaseIterable {
    case protagonist
    case antagonist
    case deuteragonist
    case supporting
    case minor
    case mentioned

    var displayName: String {
        switch self {
        case .protagonist: return "Protagonist"
        case .antagonist: return "Antagonist"
        case .deuteragonist: return "Deuteragonist"
        case .supporting: return "Supporting"
        case .minor: return "Minor"
        case .mentioned: return "Mentioned"
        }
    }

    var color: Color {
        switch self {
        case .protagonist: return .blue
        case .antagonist: return .red
        case .deuteragonist: return .purple
        case .supporting: return .green
        case .minor: return .gray
        case .mentioned: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .protagonist: return "star.fill"
        case .antagonist: return "bolt.fill"
        case .deuteragonist: return "star.leadinghalf.filled"
        case .supporting: return "person.fill"
        case .minor: return "person"
        case .mentioned: return "text.quote"
        }
    }

    var sortOrder: Int {
        switch self {
        case .protagonist: return 0
        case .antagonist: return 1
        case .deuteragonist: return 2
        case .supporting: return 3
        case .minor: return 4
        case .mentioned: return 5
        }
    }
}

// MARK: - Character Data Source

enum CharacterDataSource: String, Codable {
    case wikidata
    case editorial
    case community

    var displayName: String {
        switch self {
        case .wikidata: return "Wikidata"
        case .editorial: return "Editorial"
        case .community: return "Community"
        }
    }

    var icon: String {
        switch self {
        case .wikidata: return "globe"
        case .editorial: return "checkmark.seal.fill"
        case .community: return "person.3.fill"
        }
    }

    var reliabilityColor: Color {
        switch self {
        case .wikidata: return .blue
        case .editorial: return .green
        case .community: return .orange
        }
    }
}

// MARK: - Personality Trait

struct PersonalityTrait: Codable, Identifiable {
    let id: String
    let trait: String
    let evidence: String?
    let chapterReference: Int?

    init(trait: String, evidence: String? = nil, chapterReference: Int? = nil) {
        self.id = UUID().uuidString
        self.trait = trait
        self.evidence = evidence
        self.chapterReference = chapterReference
    }
}

// MARK: - Character Relationship

struct CharacterRelationship: Codable, Identifiable {
    let id: String
    let targetCharacterId: String
    let targetCharacterName: String
    let type: RelationshipType
    let description: String?
    let sentiment: RelationshipSentiment
    let strength: Double // 0-1
    let evolutionNotes: String? // How the relationship changes
    let keyMoments: [RelationshipMoment]?
}

// MARK: - Relationship Type

enum RelationshipType: String, Codable, CaseIterable {
    // Family
    case parent
    case child
    case sibling
    case spouse
    case relative

    // Social
    case friend
    case enemy
    case rival
    case mentor
    case student
    case colleague
    case servant
    case master

    // Romantic
    case lover
    case exLover
    case crush
    case admirer
    case betrothed

    // Other
    case ally
    case acquaintance
    case unknown

    var displayName: String {
        switch self {
        case .parent: return "Parent"
        case .child: return "Child"
        case .sibling: return "Sibling"
        case .spouse: return "Spouse"
        case .relative: return "Relative"
        case .friend: return "Friend"
        case .enemy: return "Enemy"
        case .rival: return "Rival"
        case .mentor: return "Mentor"
        case .student: return "Student"
        case .colleague: return "Colleague"
        case .servant: return "Servant"
        case .master: return "Master"
        case .lover: return "Lover"
        case .exLover: return "Ex-Lover"
        case .crush: return "Crush"
        case .admirer: return "Admirer"
        case .betrothed: return "Betrothed"
        case .ally: return "Ally"
        case .acquaintance: return "Acquaintance"
        case .unknown: return "Unknown"
        }
    }

    var icon: String {
        switch self {
        case .parent, .child: return "figure.2.and.child.holdinghands"
        case .sibling: return "person.2.fill"
        case .spouse: return "heart.fill"
        case .relative: return "person.3.fill"
        case .friend: return "hand.thumbsup.fill"
        case .enemy: return "bolt.fill"
        case .rival: return "figure.fencing"
        case .mentor, .student: return "graduationcap.fill"
        case .colleague: return "briefcase.fill"
        case .servant, .master: return "crown.fill"
        case .lover, .crush, .admirer, .betrothed: return "heart.fill"
        case .exLover: return "heart.slash.fill"
        case .ally: return "shield.fill"
        case .acquaintance: return "person.badge.plus"
        case .unknown: return "questionmark.circle"
        }
    }

    var lineColor: Color {
        switch self {
        case .parent, .child, .sibling, .spouse, .relative:
            return .orange
        case .friend, .ally:
            return .green
        case .enemy, .rival:
            return .red
        case .mentor, .student, .colleague:
            return .blue
        case .servant, .master:
            return .purple
        case .lover, .crush, .admirer, .betrothed:
            return .pink
        case .exLover:
            return .gray
        case .acquaintance, .unknown:
            return .secondary
        }
    }
}

// MARK: - Relationship Sentiment

enum RelationshipSentiment: String, Codable {
    case positive
    case negative
    case neutral
    case complex
    case evolving

    var color: Color {
        switch self {
        case .positive: return .green
        case .negative: return .red
        case .neutral: return .gray
        case .complex: return .purple
        case .evolving: return .orange
        }
    }
}

// MARK: - Relationship Moment

struct RelationshipMoment: Codable, Identifiable {
    let id: String
    let chapterIndex: Int
    let description: String
    let quote: String?
    let sentiment: RelationshipSentiment

    init(chapterIndex: Int, description: String, quote: String? = nil, sentiment: RelationshipSentiment) {
        self.id = UUID().uuidString
        self.chapterIndex = chapterIndex
        self.description = description
        self.quote = quote
        self.sentiment = sentiment
    }
}

// MARK: - Character Map Response

struct CharacterMapResponse: Codable {
    let bookId: String
    let characters: [Character]
    let relationships: [CharacterRelationship]
    let analyzedChapters: Int
    let totalChapters: Int
    let lastAnalyzedAt: Date
    let version: Int
    let dataSource: CharacterDataSource?
    let reliability: String? // "high", "medium", "low"
}

// MARK: - Character Analysis Request

struct CharacterAnalysisRequest: Codable {
    let bookId: String
    let forceReanalyze: Bool
    let maxCharacters: Int?
    let includeMinorCharacters: Bool
}

// MARK: - Character Node (for Graph Layout)

struct CharacterNode: Identifiable {
    let id: String
    let character: Character
    var position: CGPoint
    var velocity: CGPoint
    var isFixed: Bool

    init(character: Character, position: CGPoint = .zero) {
        self.id = character.id
        self.character = character
        self.position = position
        self.velocity = .zero
        self.isFixed = false
    }

    var size: CGFloat {
        switch character.role {
        case .protagonist: return 80
        case .antagonist: return 70
        case .deuteragonist: return 65
        case .supporting: return 55
        case .minor: return 45
        case .mentioned: return 35
        }
    }
}

// MARK: - Character Edge (for Graph Layout)

struct CharacterEdge: Identifiable {
    let id: String
    let sourceId: String
    let targetId: String
    let relationship: CharacterRelationship

    var color: Color {
        relationship.type.lineColor
    }

    var lineWidth: CGFloat {
        CGFloat(relationship.strength * 3 + 1)
    }
}

// MARK: - Character Filter

struct CharacterFilter {
    var roles: Set<CharacterRole> = Set(CharacterRole.allCases)
    var relationshipTypes: Set<RelationshipType> = Set(RelationshipType.allCases)
    var minimumImportance: Double = 0
    var searchText: String = ""

    var isDefault: Bool {
        roles.count == CharacterRole.allCases.count &&
        relationshipTypes.count == RelationshipType.allCases.count &&
        minimumImportance == 0 &&
        searchText.isEmpty
    }

    func matches(_ character: Character) -> Bool {
        // Role filter
        guard roles.contains(character.role) else { return false }

        // Importance filter
        guard character.importanceScore >= minimumImportance else { return false }

        // Search filter
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let nameMatches = character.name.lowercased().contains(searchLower)
            let aliasMatches = character.aliases.contains { $0.lowercased().contains(searchLower) }
            guard nameMatches || aliasMatches else { return false }
        }

        return true
    }
}
