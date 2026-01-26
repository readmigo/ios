import Foundation
import CoreData
import SwiftUI

// MARK: - Data Models

/// Currently reading book data (stored locally)
struct CurrentlyReading {
    let bookId: String
    let book: Book
    let currentChapter: Int
    let chapterId: String?
    let scrollPosition: Double
    let lastReadAt: Date
}

/// Reading progress for a specific book
struct BookReadingProgress {
    let bookId: String
    let chapterId: String?
    let currentChapter: Int
    let scrollPosition: Double
    let currentPage: Int
    let totalPages: Int
    let lastReadAt: Date
}

// MARK: - ReadingProgressStore

@MainActor
class ReadingProgressStore: ObservableObject {
    static let shared = ReadingProgressStore()

    // MARK: - Published Properties

    /// Local currently reading (from Core Data, for guests)
    @Published private(set) var currentlyReading: CurrentlyReading?

    /// Cloud library cache (for authenticated users)
    @Published private(set) var cloudLibrary: [UserBook] = []

    /// Loading state
    @Published var isLoading = false
    @Published var isSyncing = false

    private let container: NSPersistentContainer
    private let maxStoredBooks = 100

    // MARK: - Merged Data (for display)

    /// Get merged currently reading book (local + cloud, newer wins)
    var mergedCurrentlyReading: CurrentlyReading? {
        let local = currentlyReading
        let cloud = cloudCurrentlyReading

        // If only one exists, return it
        guard let local = local else { return cloud }
        guard let cloud = cloud else { return local }

        // Both exist - return the one with newer lastReadAt
        return local.lastReadAt > cloud.lastReadAt ? local : cloud
    }

    /// Convert cloud library's most recent reading book to CurrentlyReading
    private var cloudCurrentlyReading: CurrentlyReading? {
        // Find the most recently read book from cloud library
        guard let mostRecent = cloudLibrary
            .filter({ $0.status == .reading && $0.lastReadAt != nil })
            .sorted(by: { ($0.lastReadAt ?? .distantPast) > ($1.lastReadAt ?? .distantPast) })
            .first else {
            return nil
        }

        return CurrentlyReading(
            bookId: mostRecent.book.id,
            book: mostRecent.book,
            currentChapter: mostRecent.safeCurrentChapterIndex,
            chapterId: nil,
            scrollPosition: mostRecent.safeProgress,
            lastReadAt: mostRecent.lastReadAt ?? Date()
        )
    }

    /// Get merged progress for a specific book
    func getMergedProgress(for bookId: String) -> BookReadingProgress? {
        let local = getProgress(for: bookId)
        let cloud = getCloudProgress(for: bookId)

        guard let local = local else { return cloud }
        guard let cloud = cloud else { return local }

        // Return the one with newer lastReadAt
        return local.lastReadAt > cloud.lastReadAt ? local : cloud
    }

    /// Get cloud progress for a specific book
    private func getCloudProgress(for bookId: String) -> BookReadingProgress? {
        guard let userBook = cloudLibrary.first(where: { $0.book.id == bookId }) else {
            return nil
        }

        return BookReadingProgress(
            bookId: bookId,
            chapterId: nil,
            currentChapter: userBook.safeCurrentChapterIndex,
            scrollPosition: userBook.safeProgress,
            currentPage: Int(userBook.safeProgress * Double(userBook.book.chapterCount ?? 1)),
            totalPages: userBook.book.chapterCount ?? 1,
            lastReadAt: userBook.lastReadAt ?? Date()
        )
    }

    private init() {
        // Create Core Data model programmatically
        let model = Self.createManagedObjectModel()
        container = NSPersistentContainer(name: "ReadingProgress", managedObjectModel: model)

        container.loadPersistentStores { _, error in
            if let error = error {
                LoggingService.shared.error(.cache, "Failed to load Core Data: \(error)", component: "ReadingProgressStore")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true

        // Load currently reading on init
        loadCurrentlyReading()
    }

    // MARK: - Core Data Model Creation

    private static func createManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // CurrentlyReadingEntity
        let currentlyReadingEntity = NSEntityDescription()
        currentlyReadingEntity.name = "CurrentlyReadingEntity"
        currentlyReadingEntity.managedObjectClassName = NSStringFromClass(CurrentlyReadingEntity.self)

        let crBookId = NSAttributeDescription()
        crBookId.name = "bookId"
        crBookId.attributeType = .stringAttributeType

        let crBookJson = NSAttributeDescription()
        crBookJson.name = "bookJson"
        crBookJson.attributeType = .binaryDataAttributeType

        let crCurrentChapter = NSAttributeDescription()
        crCurrentChapter.name = "currentChapter"
        crCurrentChapter.attributeType = .integer32AttributeType
        crCurrentChapter.defaultValue = 0

        let crChapterId = NSAttributeDescription()
        crChapterId.name = "chapterId"
        crChapterId.attributeType = .stringAttributeType
        crChapterId.isOptional = true

        let crScrollPosition = NSAttributeDescription()
        crScrollPosition.name = "scrollPosition"
        crScrollPosition.attributeType = .doubleAttributeType
        crScrollPosition.defaultValue = 0.0

        let crLastReadAt = NSAttributeDescription()
        crLastReadAt.name = "lastReadAt"
        crLastReadAt.attributeType = .dateAttributeType

        currentlyReadingEntity.properties = [crBookId, crBookJson, crCurrentChapter, crChapterId, crScrollPosition, crLastReadAt]

        // BookReadingProgressEntity
        let progressEntity = NSEntityDescription()
        progressEntity.name = "BookReadingProgressEntity"
        progressEntity.managedObjectClassName = NSStringFromClass(BookReadingProgressEntity.self)

        let prBookId = NSAttributeDescription()
        prBookId.name = "bookId"
        prBookId.attributeType = .stringAttributeType

        let prChapterId = NSAttributeDescription()
        prChapterId.name = "chapterId"
        prChapterId.attributeType = .stringAttributeType
        prChapterId.isOptional = true

        let prCurrentChapter = NSAttributeDescription()
        prCurrentChapter.name = "currentChapter"
        prCurrentChapter.attributeType = .integer32AttributeType
        prCurrentChapter.defaultValue = 0

        let prScrollPosition = NSAttributeDescription()
        prScrollPosition.name = "scrollPosition"
        prScrollPosition.attributeType = .doubleAttributeType
        prScrollPosition.defaultValue = 0.0

        let prCurrentPage = NSAttributeDescription()
        prCurrentPage.name = "currentPage"
        prCurrentPage.attributeType = .integer32AttributeType
        prCurrentPage.defaultValue = 1

        let prTotalPages = NSAttributeDescription()
        prTotalPages.name = "totalPages"
        prTotalPages.attributeType = .integer32AttributeType
        prTotalPages.defaultValue = 1

        let prLastReadAt = NSAttributeDescription()
        prLastReadAt.name = "lastReadAt"
        prLastReadAt.attributeType = .dateAttributeType

        progressEntity.properties = [prBookId, prChapterId, prCurrentChapter, prScrollPosition, prCurrentPage, prTotalPages, prLastReadAt]

        model.entities = [currentlyReadingEntity, progressEntity]
        return model
    }

    // MARK: - Currently Reading

    private func loadCurrentlyReading() {
        let context = container.viewContext
        let request = NSFetchRequest<CurrentlyReadingEntity>(entityName: "CurrentlyReadingEntity")
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                currentlyReading = entity.toModel()
            }
        } catch {
            LoggingService.shared.error(.cache, "Failed to load currently reading: \(error)", component: "ReadingProgressStore")
        }
    }

    /// Get currently reading book
    func getCurrentlyReading() -> CurrentlyReading? {
        return currentlyReading
    }

    /// Set currently reading book (replaces previous)
    func setCurrentlyReading(book: Book, chapter: Int, chapterId: String?, position: Double) {
        let context = container.viewContext

        // Delete existing
        let deleteRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CurrentlyReadingEntity")
        let batchDelete = NSBatchDeleteRequest(fetchRequest: deleteRequest)

        do {
            try context.execute(batchDelete)

            // Create new
            let entity = CurrentlyReadingEntity(context: context)
            entity.bookId = book.id
            entity.bookJson = try? JSONEncoder().encode(book)
            entity.currentChapter = Int32(chapter)
            entity.chapterId = chapterId
            entity.scrollPosition = position
            entity.lastReadAt = Date()

            try context.save()

            // Update published property
            currentlyReading = CurrentlyReading(
                bookId: book.id,
                book: book,
                currentChapter: chapter,
                chapterId: chapterId,
                scrollPosition: position,
                lastReadAt: Date()
            )

            LoggingService.shared.info(.cache, "Set currently reading: \(book.title), chapter \(chapter)", component: "ReadingProgressStore")
        } catch {
            LoggingService.shared.error(.cache, "Failed to set currently reading: \(error)", component: "ReadingProgressStore")
        }
    }

    // MARK: - Book Reading Progress

    /// Get reading progress for a specific book
    func getProgress(for bookId: String) -> BookReadingProgress? {
        let context = container.viewContext
        let request = NSFetchRequest<BookReadingProgressEntity>(entityName: "BookReadingProgressEntity")
        request.predicate = NSPredicate(format: "bookId == %@", bookId)
        request.fetchLimit = 1

        do {
            if let entity = try context.fetch(request).first {
                return entity.toModel()
            }
        } catch {
            LoggingService.shared.error(.cache, "Failed to get progress for \(bookId): \(error)", component: "ReadingProgressStore")
        }

        return nil
    }

    /// Save reading progress for a book
    func saveProgress(
        bookId: String,
        chapterId: String?,
        chapter: Int,
        position: Double,
        page: Int = 1,
        totalPages: Int = 1
    ) {
        let context = container.viewContext

        // Find existing or create new
        let request = NSFetchRequest<BookReadingProgressEntity>(entityName: "BookReadingProgressEntity")
        request.predicate = NSPredicate(format: "bookId == %@", bookId)
        request.fetchLimit = 1

        do {
            let entity: BookReadingProgressEntity
            if let existing = try context.fetch(request).first {
                entity = existing
            } else {
                entity = BookReadingProgressEntity(context: context)
                entity.bookId = bookId
            }

            entity.chapterId = chapterId
            entity.currentChapter = Int32(chapter)
            entity.scrollPosition = position
            entity.currentPage = Int32(page)
            entity.totalPages = Int32(totalPages)
            entity.lastReadAt = Date()

            try context.save()

            // Enforce LRU limit
            enforceStorageLimit()

            LoggingService.shared.debug(.cache, "Saved progress: book=\(bookId), chapter=\(chapter), position=\(Int(position * 100))%", component: "ReadingProgressStore")
        } catch {
            LoggingService.shared.error(.cache, "Failed to save progress: \(error)", component: "ReadingProgressStore")
        }
    }

    /// Save progress and update currently reading
    func saveProgressAndSetCurrentlyReading(
        book: Book,
        chapterId: String?,
        chapter: Int,
        position: Double,
        page: Int = 1,
        totalPages: Int = 1
    ) {
        saveProgress(
            bookId: book.id,
            chapterId: chapterId,
            chapter: chapter,
            position: position,
            page: page,
            totalPages: totalPages
        )
        setCurrentlyReading(book: book, chapter: chapter, chapterId: chapterId, position: position)
    }

    // MARK: - Storage Management

    private func enforceStorageLimit() {
        let context = container.viewContext
        let request = NSFetchRequest<BookReadingProgressEntity>(entityName: "BookReadingProgressEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "lastReadAt", ascending: false)]

        do {
            let allProgress = try context.fetch(request)
            if allProgress.count > maxStoredBooks {
                // Delete oldest entries beyond limit
                let toDelete = allProgress.suffix(from: maxStoredBooks)
                for entity in toDelete {
                    context.delete(entity)
                }
                try context.save()
                LoggingService.shared.info(.cache, "Cleaned up \(toDelete.count) old reading progress entries", component: "ReadingProgressStore")
            }
        } catch {
            LoggingService.shared.error(.cache, "Failed to enforce storage limit: \(error)", component: "ReadingProgressStore")
        }
    }

    /// Clear all stored data (for debugging/logout)
    func clearAll() {
        let context = container.viewContext

        let entities = ["CurrentlyReadingEntity", "BookReadingProgressEntity"]
        for entityName in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let batchDelete = NSBatchDeleteRequest(fetchRequest: request)
            try? context.execute(batchDelete)
        }

        try? context.save()
        currentlyReading = nil

        LoggingService.shared.info(.cache, "Cleared all reading progress data", component: "ReadingProgressStore")
    }

    // MARK: - Cloud Sync

    /// Fetch reading progress from server (for authenticated users)
    func fetchFromServer() async {
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.cache, "Not authenticated, skipping cloud fetch", component: "ReadingProgressStore")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: UserLibraryResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.readingLibrary
            )
            cloudLibrary = response.books
            LoggingService.shared.info(.cache, "Fetched \(response.books.count) books from cloud library", component: "ReadingProgressStore")
        } catch {
            LoggingService.shared.error(.cache, "Failed to fetch cloud library: \(error)", component: "ReadingProgressStore")
        }
    }

    /// Sync local progress to server (for authenticated users)
    /// Called when exiting reader
    func syncToServer(bookId: String, chapter: Int, position: Double) async {
        guard AuthManager.shared.isAuthenticated else {
            LoggingService.shared.debug(.cache, "Not authenticated, skipping sync", component: "ReadingProgressStore")
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        do {
            let body = UpdateProgressRequest(
                currentChapter: chapter,
                currentPosition: nil,
                progressPercent: position,
                status: nil
            )
            let _: UserBook = try await APIClient.shared.request(
                endpoint: APIEndpoints.updateProgress(bookId),
                method: .patch,
                body: body
            )
            LoggingService.shared.info(.cache, "Synced progress to server: book=\(bookId), chapter=\(chapter)", component: "ReadingProgressStore")

            // Refresh cloud library after sync
            await fetchFromServer()
        } catch {
            LoggingService.shared.error(.cache, "Failed to sync progress to server: \(error)", component: "ReadingProgressStore")
        }
    }

    /// Called when user logs out - clear cloud cache
    func handleLogout() {
        cloudLibrary = []
        LoggingService.shared.info(.cache, "Cleared cloud library cache on logout", component: "ReadingProgressStore")
    }

    /// Called when user logs in - merge and sync
    func handleLogin() async {
        // 1. Fetch cloud data
        await fetchFromServer()

        // 2. If local has more recent progress, sync to server
        if let local = currentlyReading,
           let cloud = cloudCurrentlyReading {
            if local.lastReadAt > cloud.lastReadAt && local.bookId == cloud.bookId {
                // Local is newer, sync to server
                await syncToServer(
                    bookId: local.bookId,
                    chapter: local.currentChapter,
                    position: local.scrollPosition
                )
            }
        } else if let local = currentlyReading {
            // Only local exists, sync to server
            await syncToServer(
                bookId: local.bookId,
                chapter: local.currentChapter,
                position: local.scrollPosition
            )
        }

        LoggingService.shared.info(.cache, "Completed login sync for reading progress", component: "ReadingProgressStore")
    }
}

// MARK: - Core Data Entities

@objc(CurrentlyReadingEntity)
class CurrentlyReadingEntity: NSManagedObject {
    @NSManaged var bookId: String
    @NSManaged var bookJson: Data?
    @NSManaged var currentChapter: Int32
    @NSManaged var chapterId: String?
    @NSManaged var scrollPosition: Double
    @NSManaged var lastReadAt: Date?

    func toModel() -> CurrentlyReading? {
        guard let bookJson = bookJson,
              let book = try? JSONDecoder().decode(Book.self, from: bookJson) else {
            return nil
        }

        return CurrentlyReading(
            bookId: bookId,
            book: book,
            currentChapter: Int(currentChapter),
            chapterId: chapterId,
            scrollPosition: scrollPosition,
            lastReadAt: lastReadAt ?? Date()
        )
    }
}

@objc(BookReadingProgressEntity)
class BookReadingProgressEntity: NSManagedObject {
    @NSManaged var bookId: String
    @NSManaged var chapterId: String?
    @NSManaged var currentChapter: Int32
    @NSManaged var scrollPosition: Double
    @NSManaged var currentPage: Int32
    @NSManaged var totalPages: Int32
    @NSManaged var lastReadAt: Date?

    func toModel() -> BookReadingProgress {
        return BookReadingProgress(
            bookId: bookId,
            chapterId: chapterId,
            currentChapter: Int(currentChapter),
            scrollPosition: scrollPosition,
            currentPage: Int(currentPage),
            totalPages: Int(totalPages),
            lastReadAt: lastReadAt ?? Date()
        )
    }
}
