import Foundation
import SwiftUI

/// Manages search history persistence and retrieval
@MainActor
class SearchHistoryManager: ObservableObject {
    static let shared = SearchHistoryManager()

    private let userDefaultsKey = "searchHistory"
    private let maxHistoryCount = 20

    @Published private(set) var history: [String] = []

    private init() {
        loadHistory()
    }

    // MARK: - Public Methods

    /// Add a search query to history
    func addSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Remove if already exists (will be re-added at top)
        history.removeAll { $0.lowercased() == trimmed.lowercased() }

        // Insert at beginning
        history.insert(trimmed, at: 0)

        // Limit history size
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    /// Remove a specific query from history
    func removeSearch(_ query: String) {
        history.removeAll { $0 == query }
        saveHistory()
    }

    /// Clear all search history
    func clearHistory() {
        history = []
        saveHistory()
    }

    // MARK: - Private Methods

    private func loadHistory() {
        if let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey) {
            history = saved
        }
    }

    private func saveHistory() {
        UserDefaults.standard.set(history, forKey: userDefaultsKey)
    }
}
