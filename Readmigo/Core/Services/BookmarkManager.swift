import Foundation
import Combine

@MainActor
class BookmarkManager: ObservableObject {
    static let shared = BookmarkManager()

    // MARK: - Published Properties

    @Published var bookmarks: [String: [Bookmark]] = [:] // bookId -> bookmarks
    @Published var highlights: [String: [Bookmark]] = [:] // bookId -> highlights
    @Published var annotations: [String: [Bookmark]] = [:] // bookId -> annotations
    @Published var navigationHistory: [NavigationHistoryItem] = []
    @Published var readingPositions: [String: ReadingPosition] = [:] // bookId -> position
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Private Properties

    private let maxHistoryItems = 50
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let userDefaultsKey = "bookmarkManagerData"
    private var syncTask: Task<Void, Never>?

    // MARK: - Initialization

    private init() {
        loadLocalData()
    }

    // MARK: - Local Storage

    private func loadLocalData() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let stored = try? decoder.decode(StoredBookmarkData.self, from: data) {
            self.bookmarks = stored.bookmarks
            self.highlights = stored.highlights
            self.annotations = stored.annotations
            self.navigationHistory = stored.navigationHistory
            self.readingPositions = stored.readingPositions
        }
    }

    private func saveLocalData() {
        let stored = StoredBookmarkData(
            bookmarks: bookmarks,
            highlights: highlights,
            annotations: annotations,
            navigationHistory: navigationHistory,
            readingPositions: readingPositions
        )
        if let data = try? encoder.encode(stored) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    // MARK: - Fetch Bookmarks for Book

    func fetchBookmarks(bookId: String) async {
        isLoading = true
        error = nil

        do {
            // Fetch bookmarks, highlights, and annotations in parallel
            async let bookmarksResult: [Bookmark] = fetchBookmarksOnly(bookId: bookId)
            async let highlightsResult: [Bookmark] = fetchHighlightsOnly(bookId: bookId)

            let (fetchedBookmarks, fetchedHighlights) = await (
                try bookmarksResult,
                try highlightsResult
            )

            bookmarks[bookId] = fetchedBookmarks

            // Separate highlights and annotations
            var newHighlights: [Bookmark] = []
            var newAnnotations: [Bookmark] = []
            for item in fetchedHighlights {
                if item.note != nil && !item.note!.isEmpty {
                    newAnnotations.append(item)
                } else {
                    newHighlights.append(item)
                }
            }
            highlights[bookId] = newHighlights
            annotations[bookId] = newAnnotations

            saveLocalData()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func fetchBookmarksOnly(bookId: String) async throws -> [Bookmark] {
        let response: [Bookmark] = try await APIClient.shared.request(
            endpoint: "/books/\(bookId)/bookmarks"
        )
        return response
    }

    private func fetchHighlightsOnly(bookId: String) async throws -> [Bookmark] {
        let response: HighlightsResponse = try await APIClient.shared.request(
            endpoint: "/books/\(bookId)/highlights"
        )
        return response.highlights.map { $0.toBookmark() }
    }

    // MARK: - Create Bookmark

    func createBookmark(
        bookId: String,
        chapterId: String,
        position: BookmarkPosition,
        type: BookmarkType = .bookmark,
        title: String? = nil,
        note: String? = nil,
        highlightColor: HighlightColor? = nil,
        selectedText: String? = nil
    ) async -> Bookmark? {
        // Use different endpoints based on type
        if type == .bookmark {
            return await createBookmarkOnly(
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                title: title
            )
        } else {
            return await createHighlightOnly(
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                selectedText: selectedText ?? "",
                color: highlightColor ?? .yellow,
                note: note
            )
        }
    }

    private func createBookmarkOnly(
        bookId: String,
        chapterId: String,
        position: BookmarkPosition,
        title: String?
    ) async -> Bookmark? {
        let request = CreateBookmarkAPIRequest(
            bookId: bookId,
            chapterId: chapterId,
            chapterIndex: position.chapterIndex,
            scrollPercentage: position.scrollPercentage,
            title: title
        )

        do {
            let response: BookmarkAPIResponse = try await APIClient.shared.request(
                endpoint: "/bookmarks",
                method: .post,
                body: request
            )

            let bookmark = response.toBookmark()
            addBookmarkLocally(bookmark)
            saveLocalData()
            return bookmark
        } catch {
            // Create local bookmark for offline
            let localBookmark = Bookmark(
                id: UUID().uuidString,
                bookId: bookId,
                chapterId: chapterId,
                userId: "",
                position: position,
                type: .bookmark,
                title: title,
                note: nil,
                highlightColor: nil,
                selectedText: nil,
                createdAt: Date(),
                updatedAt: Date(),
                syncedAt: nil
            )
            addBookmarkLocally(localBookmark)
            saveLocalData()
            return localBookmark
        }
    }

    private func createHighlightOnly(
        bookId: String,
        chapterId: String,
        position: BookmarkPosition,
        selectedText: String,
        color: HighlightColor,
        note: String?
    ) async -> Bookmark? {
        let request = CreateHighlightAPIRequest(
            bookId: bookId,
            chapterId: chapterId,
            chapterIndex: position.chapterIndex,
            scrollPercentage: position.scrollPercentage,
            selectedText: selectedText,
            color: color.rawValue,
            cfiPath: position.cfiPath
        )

        do {
            let response: HighlightAPIResponse = try await APIClient.shared.request(
                endpoint: "/highlights",
                method: .post,
                body: request
            )

            var bookmark = response.toBookmark()

            // If there's a note, create annotation
            if let note = note, !note.isEmpty {
                _ = await createAnnotationForHighlight(highlightId: bookmark.id, note: note)
                bookmark = Bookmark(
                    id: bookmark.id,
                    bookId: bookmark.bookId,
                    chapterId: bookmark.chapterId,
                    userId: bookmark.userId,
                    position: bookmark.position,
                    type: .annotation,
                    title: bookmark.title,
                    note: note,
                    highlightColor: bookmark.highlightColor,
                    selectedText: bookmark.selectedText,
                    createdAt: bookmark.createdAt,
                    updatedAt: Date(),
                    syncedAt: bookmark.syncedAt
                )
            }

            addBookmarkLocally(bookmark)
            saveLocalData()
            return bookmark
        } catch {
            // Create local highlight for offline
            let localBookmark = Bookmark(
                id: UUID().uuidString,
                bookId: bookId,
                chapterId: chapterId,
                userId: "",
                position: position,
                type: note != nil ? .annotation : .highlight,
                title: nil,
                note: note,
                highlightColor: color,
                selectedText: selectedText,
                createdAt: Date(),
                updatedAt: Date(),
                syncedAt: nil
            )
            addBookmarkLocally(localBookmark)
            saveLocalData()
            return localBookmark
        }
    }

    private func createAnnotationForHighlight(highlightId: String, note: String) async -> Bool {
        let request = CreateAnnotationAPIRequest(
            highlightId: highlightId,
            content: note
        )

        do {
            let _: AnnotationAPIResponse = try await APIClient.shared.request(
                endpoint: "/annotations",
                method: .post,
                body: request
            )
            return true
        } catch {
            return false
        }
    }

    private func addBookmarkLocally(_ bookmark: Bookmark) {
        switch bookmark.type {
        case .bookmark:
            if bookmarks[bookmark.bookId] == nil {
                bookmarks[bookmark.bookId] = []
            }
            bookmarks[bookmark.bookId]?.append(bookmark)
        case .highlight:
            if highlights[bookmark.bookId] == nil {
                highlights[bookmark.bookId] = []
            }
            highlights[bookmark.bookId]?.append(bookmark)
        case .annotation:
            if annotations[bookmark.bookId] == nil {
                annotations[bookmark.bookId] = []
            }
            annotations[bookmark.bookId]?.append(bookmark)
        }
    }

    // MARK: - Update Bookmark

    func updateBookmark(
        _ bookmark: Bookmark,
        title: String? = nil,
        note: String? = nil,
        highlightColor: HighlightColor? = nil
    ) async {
        // Use different endpoints based on type
        if bookmark.type == .bookmark {
            // Bookmarks don't have a PATCH endpoint - delete and recreate
            // For now, just update locally
            let updated = Bookmark(
                id: bookmark.id,
                bookId: bookmark.bookId,
                chapterId: bookmark.chapterId,
                userId: bookmark.userId,
                position: bookmark.position,
                type: bookmark.type,
                title: title ?? bookmark.title,
                note: nil,
                highlightColor: nil,
                selectedText: nil,
                createdAt: bookmark.createdAt,
                updatedAt: Date(),
                syncedAt: nil
            )
            updateBookmarkLocally(updated)
            saveLocalData()
        } else {
            // Update highlight color
            if let newColor = highlightColor {
                let request = UpdateHighlightAPIRequest(color: newColor.rawValue)
                do {
                    let _: HighlightAPIResponse = try await APIClient.shared.request(
                        endpoint: "/highlights/\(bookmark.id)",
                        method: .patch,
                        body: request
                    )
                } catch {
                    print("Failed to update highlight color: \(error)")
                }
            }

            // Update or create annotation for note
            if let newNote = note {
                // Check if annotation exists
                if bookmark.note != nil && !bookmark.note!.isEmpty {
                    // Update existing annotation - need annotation ID
                    // For now, we'll update locally
                } else if !newNote.isEmpty {
                    // Create new annotation
                    _ = await createAnnotationForHighlight(highlightId: bookmark.id, note: newNote)
                }
            }

            let updated = Bookmark(
                id: bookmark.id,
                bookId: bookmark.bookId,
                chapterId: bookmark.chapterId,
                userId: bookmark.userId,
                position: bookmark.position,
                type: (note != nil && !note!.isEmpty) ? .annotation : bookmark.type,
                title: title ?? bookmark.title,
                note: note ?? bookmark.note,
                highlightColor: highlightColor ?? bookmark.highlightColor,
                selectedText: bookmark.selectedText,
                createdAt: bookmark.createdAt,
                updatedAt: Date(),
                syncedAt: nil
            )

            updateBookmarkLocally(updated)
            saveLocalData()
        }
    }

    private func updateBookmarkLocally(_ bookmark: Bookmark) {
        switch bookmark.type {
        case .bookmark:
            if let index = bookmarks[bookmark.bookId]?.firstIndex(where: { $0.id == bookmark.id }) {
                bookmarks[bookmark.bookId]?[index] = bookmark
            }
        case .highlight:
            if let index = highlights[bookmark.bookId]?.firstIndex(where: { $0.id == bookmark.id }) {
                highlights[bookmark.bookId]?[index] = bookmark
            }
        case .annotation:
            if let index = annotations[bookmark.bookId]?.firstIndex(where: { $0.id == bookmark.id }) {
                annotations[bookmark.bookId]?[index] = bookmark
            }
        }
    }

    // MARK: - Delete Bookmark

    func deleteBookmark(_ bookmark: Bookmark) async {
        // Use different endpoints based on type
        let endpoint: String
        switch bookmark.type {
        case .bookmark:
            endpoint = "/bookmarks/\(bookmark.id)"
        case .highlight, .annotation:
            endpoint = "/highlights/\(bookmark.id)"
        }

        do {
            try await APIClient.shared.requestVoid(
                endpoint: endpoint,
                method: .delete
            )
        } catch {
            print("Failed to delete bookmark from server: \(error)")
        }

        // Remove locally
        removeBookmarkLocally(bookmark)
        saveLocalData()
    }

    private func removeBookmarkLocally(_ bookmark: Bookmark) {
        switch bookmark.type {
        case .bookmark:
            bookmarks[bookmark.bookId]?.removeAll { $0.id == bookmark.id }
        case .highlight:
            highlights[bookmark.bookId]?.removeAll { $0.id == bookmark.id }
        case .annotation:
            annotations[bookmark.bookId]?.removeAll { $0.id == bookmark.id }
        }
    }

    // MARK: - Quick Bookmark Toggle

    func toggleBookmark(
        bookId: String,
        chapterId: String,
        position: BookmarkPosition
    ) async -> Bool {
        // Check if bookmark exists at this position
        if let existing = bookmarks[bookId]?.first(where: { $0.position == position }) {
            await deleteBookmark(existing)
            return false
        } else {
            _ = await createBookmark(
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                type: .bookmark
            )
            return true
        }
    }

    // MARK: - Create Highlight

    func createHighlight(
        bookId: String,
        chapterId: String,
        position: BookmarkPosition,
        selectedText: String,
        color: HighlightColor = .yellow,
        note: String? = nil
    ) async -> Bookmark? {
        return await createBookmark(
            bookId: bookId,
            chapterId: chapterId,
            position: position,
            type: note != nil ? .annotation : .highlight,
            note: note,
            highlightColor: color,
            selectedText: selectedText
        )
    }

    // MARK: - Navigation History

    func addToHistory(
        bookId: String,
        chapterId: String,
        position: BookmarkPosition,
        chapterTitle: String?
    ) {
        let item = NavigationHistoryItem(
            id: UUID().uuidString,
            bookId: bookId,
            chapterId: chapterId,
            position: position,
            timestamp: Date(),
            chapterTitle: chapterTitle
        )

        navigationHistory.insert(item, at: 0)

        // Limit history size
        if navigationHistory.count > maxHistoryItems {
            navigationHistory = Array(navigationHistory.prefix(maxHistoryItems))
        }

        saveLocalData()
    }

    func getHistory(for bookId: String) -> [NavigationHistoryItem] {
        navigationHistory.filter { $0.bookId == bookId }
    }

    func clearHistory(for bookId: String? = nil) {
        if let bookId = bookId {
            navigationHistory.removeAll { $0.bookId == bookId }
        } else {
            navigationHistory.removeAll()
        }
        saveLocalData()
    }

    // MARK: - Reading Position

    func updateReadingPosition(
        bookId: String,
        chapterId: String,
        chapterIndex: Int,
        scrollPercentage: Double
    ) {
        let position = ReadingPosition.current(
            bookId: bookId,
            chapterId: chapterId,
            chapterIndex: chapterIndex,
            scrollPercentage: scrollPercentage
        )

        readingPositions[bookId] = position
        saveLocalData()

        // Sync to server (debounced)
        scheduleSyncPosition(position)
    }

    func getReadingPosition(bookId: String) -> ReadingPosition? {
        readingPositions[bookId]
    }

    private func scheduleSyncPosition(_ position: ReadingPosition) {
        syncTask?.cancel()
        syncTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 second debounce
            guard !Task.isCancelled else { return }
            await syncPositionToServer(position)
        }
    }

    private func syncPositionToServer(_ position: ReadingPosition) async {
        do {
            try await APIClient.shared.requestVoid(
                endpoint: "/reading/position",
                method: .post,
                body: position
            )
        } catch {
            print("Failed to sync reading position: \(error)")
        }
    }

    // MARK: - Get All Items for Book

    func getAllItems(for bookId: String) -> [Bookmark] {
        var allItems: [Bookmark] = []
        allItems.append(contentsOf: bookmarks[bookId] ?? [])
        allItems.append(contentsOf: highlights[bookId] ?? [])
        allItems.append(contentsOf: annotations[bookId] ?? [])
        return allItems.sorted { $0.createdAt > $1.createdAt }
    }

    func getBookmarks(for bookId: String) -> [Bookmark] {
        bookmarks[bookId] ?? []
    }

    func getHighlights(for bookId: String) -> [Bookmark] {
        highlights[bookId] ?? []
    }

    func getAnnotations(for bookId: String) -> [Bookmark] {
        annotations[bookId] ?? []
    }

    func getHighlightsForChapter(bookId: String, chapterId: String) -> [Bookmark] {
        (highlights[bookId] ?? []).filter { $0.chapterId == chapterId }
    }

    // MARK: - Check if Position Has Bookmark

    func hasBookmark(bookId: String, position: BookmarkPosition) -> Bool {
        bookmarks[bookId]?.contains { $0.position == position } ?? false
    }
}

// MARK: - Stored Data Structure

private struct StoredBookmarkData: Codable {
    let bookmarks: [String: [Bookmark]]
    let highlights: [String: [Bookmark]]
    let annotations: [String: [Bookmark]]
    let navigationHistory: [NavigationHistoryItem]
    let readingPositions: [String: ReadingPosition]
}

// MARK: - API Request Models

struct CreateBookmarkAPIRequest: Codable {
    let bookId: String
    let chapterId: String
    let chapterIndex: Int
    let scrollPercentage: Double
    let title: String?
}

struct CreateHighlightAPIRequest: Codable {
    let bookId: String
    let chapterId: String
    let chapterIndex: Int
    let scrollPercentage: Double
    let selectedText: String
    let color: String
    let cfiPath: String?
}

struct CreateAnnotationAPIRequest: Codable {
    let highlightId: String
    let content: String
}

struct UpdateHighlightAPIRequest: Codable {
    let color: String
}

// MARK: - API Response Models

struct HighlightsResponse: Codable {
    let highlights: [HighlightAPIResponse]
}

struct BookmarkAPIResponse: Codable {
    let id: String
    let bookId: String
    let chapterId: String
    let userId: String
    let chapterIndex: Int?
    let scrollPercentage: Double?
    let scrollPosition: Double? // Backend field name alias
    let title: String?
    let createdAt: String
    let updatedAt: String

    func toBookmark() -> Bookmark {
        // Use scrollPercentage or scrollPosition (backend name)
        let scrollPct = scrollPercentage ?? scrollPosition ?? 0
        let position = BookmarkPosition(
            chapterIndex: chapterIndex ?? 0,
            paragraphIndex: nil,
            characterOffset: nil,
            scrollPercentage: scrollPct,
            cfiPath: nil
        )
        return Bookmark(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            userId: userId,
            position: position,
            type: .bookmark,
            title: title,
            note: nil,
            highlightColor: nil,
            selectedText: nil,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: updatedAt) ?? Date(),
            syncedAt: Date()
        )
    }
}

struct HighlightAPIResponse: Codable {
    let id: String
    let bookId: String
    let chapterId: String
    let userId: String
    let chapterIndex: Int?
    let scrollPercentage: Double?
    let selectedText: String
    let color: String
    let cfiPath: String?
    let cfiRange: String? // Backend field name alias
    let annotations: [AnnotationAPIResponse]?
    let createdAt: String
    let updatedAt: String

    func toBookmark() -> Bookmark {
        // Use cfiPath or cfiRange (backend name)
        let cfi = cfiPath ?? cfiRange
        let position = BookmarkPosition(
            chapterIndex: chapterIndex ?? 0,
            paragraphIndex: nil,
            characterOffset: nil,
            scrollPercentage: scrollPercentage ?? 0,
            cfiPath: cfi
        )
        let note = annotations?.first?.annotationContent
        let type: BookmarkType = (note != nil && !note!.isEmpty) ? .annotation : .highlight
        return Bookmark(
            id: id,
            bookId: bookId,
            chapterId: chapterId,
            userId: userId,
            position: position,
            type: type,
            title: nil,
            note: note,
            highlightColor: HighlightColor(rawValue: color),
            selectedText: selectedText,
            createdAt: ISO8601DateFormatter().date(from: createdAt) ?? Date(),
            updatedAt: ISO8601DateFormatter().date(from: updatedAt) ?? Date(),
            syncedAt: Date()
        )
    }
}

struct AnnotationAPIResponse: Codable {
    let id: String
    let highlightId: String
    let content: String?
    let note: String? // Backend field name alias
    let createdAt: String
    let updatedAt: String

    // Computed property to get the actual content
    var annotationContent: String {
        content ?? note ?? ""
    }
}
