import Foundation
import Combine

@MainActor
class CharacterMapManager: ObservableObject {
    static let shared = CharacterMapManager()

    // MARK: - Published Properties

    @Published var characters: [String: [Character]] = [:] // bookId -> characters
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var error: String?

    // MARK: - Private Properties

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cacheKey = "characterMapCache"

    // MARK: - Initialization

    private init() {
        loadFromCache()
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? decoder.decode([String: [Character]].self, from: data) {
            characters = cached
        }
    }

    private func saveToCache() {
        if let data = try? encoder.encode(characters) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Fetch Characters

    func fetchCharacters(bookId: String, forceRefresh: Bool = false) async {
        // Return cached if available and not forcing refresh
        if !forceRefresh, let cached = characters[bookId], !cached.isEmpty {
            return
        }

        isLoading = true
        error = nil

        do {
            let response: CharacterMapResponse = try await APIClient.shared.request(
                endpoint: "/books/\(bookId)/characters"
            )

            characters[bookId] = response.characters
            saveToCache()
        } catch {
            self.error = error.localizedDescription

            // Try loading from AI analysis if no existing data
            if characters[bookId]?.isEmpty ?? true {
                await analyzeCharacters(bookId: bookId)
            }
        }

        isLoading = false
    }

    // MARK: - AI Character Analysis

    func analyzeCharacters(bookId: String, includeMinor: Bool = true) async {
        isAnalyzing = true
        analysisProgress = 0
        error = nil

        do {
            let request = CharacterAnalysisRequest(
                bookId: bookId,
                forceReanalyze: true,
                maxCharacters: nil,
                includeMinorCharacters: includeMinor
            )

            // Start analysis
            let response: CharacterMapResponse = try await APIClient.shared.request(
                endpoint: "/ai/analyze-characters",
                method: .post,
                body: request
            )

            characters[bookId] = response.characters
            saveToCache()
            analysisProgress = 1.0
        } catch {
            self.error = "Character analysis failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    // MARK: - Get Characters

    func getCharacters(for bookId: String) -> [Character] {
        characters[bookId] ?? []
    }

    func getCharacter(id: String, bookId: String) -> Character? {
        characters[bookId]?.first { $0.id == id }
    }

    func getProtagonists(for bookId: String) -> [Character] {
        getCharacters(for: bookId).filter { $0.role == .protagonist }
    }

    func getAntagonists(for bookId: String) -> [Character] {
        getCharacters(for: bookId).filter { $0.role == .antagonist }
    }

    func getMainCharacters(for bookId: String) -> [Character] {
        getCharacters(for: bookId).filter {
            $0.role == .protagonist || $0.role == .antagonist || $0.role == .deuteragonist
        }
    }

    func getSupportingCharacters(for bookId: String) -> [Character] {
        getCharacters(for: bookId).filter { $0.role == .supporting }
    }

    // MARK: - Filter & Sort

    func getFilteredCharacters(for bookId: String, filter: CharacterFilter) -> [Character] {
        getCharacters(for: bookId).filter { filter.matches($0) }
    }

    func getSortedCharacters(for bookId: String, by sortMethod: CharacterSortMethod) -> [Character] {
        let chars = getCharacters(for: bookId)
        switch sortMethod {
        case .importance:
            return chars.sorted { $0.importanceScore > $1.importanceScore }
        case .appearance:
            return chars.sorted { $0.firstAppearanceChapter < $1.firstAppearanceChapter }
        case .alphabetical:
            return chars.sorted { $0.name < $1.name }
        case .role:
            return chars.sorted { $0.role.sortOrder < $1.role.sortOrder }
        case .mentions:
            return chars.sorted { $0.mentionCount > $1.mentionCount }
        }
    }

    // MARK: - Relationship Graph

    func buildGraph(for bookId: String) -> (nodes: [CharacterNode], edges: [CharacterEdge]) {
        let chars = getCharacters(for: bookId)
        var nodes: [CharacterNode] = []
        var edges: [CharacterEdge] = []

        // Create nodes
        for (index, character) in chars.enumerated() {
            let angle = (2 * .pi / Double(chars.count)) * Double(index)
            let radius: CGFloat = 200
            let position = CGPoint(
                x: 300 + radius * cos(angle),
                y: 300 + radius * sin(angle)
            )
            nodes.append(CharacterNode(character: character, position: position))
        }

        // Create edges
        for character in chars {
            for relationship in character.relationships {
                // Avoid duplicate edges
                if character.id < relationship.targetCharacterId {
                    let edge = CharacterEdge(
                        id: "\(character.id)-\(relationship.targetCharacterId)",
                        sourceId: character.id,
                        targetId: relationship.targetCharacterId,
                        relationship: relationship
                    )
                    edges.append(edge)
                }
            }
        }

        return (nodes, edges)
    }

    // MARK: - Clear Cache

    func clearCache(for bookId: String? = nil) {
        if let bookId = bookId {
            characters.removeValue(forKey: bookId)
        } else {
            characters.removeAll()
        }
        saveToCache()
    }
}

// MARK: - Sort Method

enum CharacterSortMethod: String, CaseIterable {
    case importance
    case appearance
    case alphabetical
    case role
    case mentions

    var displayName: String {
        switch self {
        case .importance: return "Importance"
        case .appearance: return "First Appearance"
        case .alphabetical: return "A-Z"
        case .role: return "Role"
        case .mentions: return "Mentions"
        }
    }

    var icon: String {
        switch self {
        case .importance: return "star"
        case .appearance: return "clock"
        case .alphabetical: return "textformat.abc"
        case .role: return "person.crop.circle"
        case .mentions: return "text.word.spacing"
        }
    }
}
