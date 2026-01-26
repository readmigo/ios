import Foundation

actor ContentCache {
    static let shared = ContentCache()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var offlineDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("OfflineContent", isDirectory: true)
    }

    private var metadataDirectory: URL {
        offlineDirectory.appendingPathComponent("metadata", isDirectory: true)
    }

    private var chaptersDirectory: URL {
        offlineDirectory.appendingPathComponent("chapters", isDirectory: true)
    }

    private var coversDirectory: URL {
        offlineDirectory.appendingPathComponent("covers", isDirectory: true)
    }

    private var cacheDirectory: URL {
        let cachePath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cachePath.appendingPathComponent("ReadmigoCache", isDirectory: true)
    }

    private init() {
        Task {
            await ensureDirectoriesExist()
        }
    }

    // MARK: - Directory Management

    private func ensureDirectoriesExist() {
        let directories = [offlineDirectory, metadataDirectory, chaptersDirectory, coversDirectory, cacheDirectory]
        for dir in directories {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    // MARK: - Chapter Content

    func saveChapterContent(_ content: ChapterContent, bookId: String) async throws {
        let bookDir = chaptersDirectory.appendingPathComponent(bookId, isDirectory: true)
        try? fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)

        let filePath = bookDir.appendingPathComponent("\(content.id).json")
        let data = try encoder.encode(content)
        try data.write(to: filePath)
    }

    func loadChapterContent(bookId: String, chapterId: String) async throws -> ChapterContent? {
        let filePath = chaptersDirectory
            .appendingPathComponent(bookId, isDirectory: true)
            .appendingPathComponent("\(chapterId).json")

        guard fileManager.fileExists(atPath: filePath.path) else { return nil }

        let data = try Data(contentsOf: filePath)
        return try decoder.decode(ChapterContent.self, from: data)
    }

    func getChapterContent(bookId: String, chapterId: String) async -> ChapterContent? {
        return try? await loadChapterContent(bookId: bookId, chapterId: chapterId)
    }

    func hasChapterContent(bookId: String, chapterId: String) async -> Bool {
        let filePath = chaptersDirectory
            .appendingPathComponent(bookId, isDirectory: true)
            .appendingPathComponent("\(chapterId).json")
        return fileManager.fileExists(atPath: filePath.path)
    }

    func deleteChapterContent(bookId: String, chapterId: String) async throws {
        let filePath = chaptersDirectory
            .appendingPathComponent(bookId, isDirectory: true)
            .appendingPathComponent("\(chapterId).json")

        if fileManager.fileExists(atPath: filePath.path) {
            try fileManager.removeItem(at: filePath)
        }
    }

    // MARK: - Book Metadata

    func saveBookMetadata(_ metadata: DownloadedBook) async throws {
        let filePath = metadataDirectory.appendingPathComponent("\(metadata.bookId).json")
        let data = try encoder.encode(metadata)
        try data.write(to: filePath)
    }

    func loadBookMetadata(bookId: String) async throws -> DownloadedBook? {
        let filePath = metadataDirectory.appendingPathComponent("\(bookId).json")
        guard fileManager.fileExists(atPath: filePath.path) else { return nil }

        let data = try Data(contentsOf: filePath)
        return try decoder.decode(DownloadedBook.self, from: data)
    }

    func loadAllBookMetadata() async throws -> [DownloadedBook] {
        guard fileManager.fileExists(atPath: metadataDirectory.path) else { return [] }

        let files = try fileManager.contentsOfDirectory(at: metadataDirectory, includingPropertiesForKeys: nil)
        var books: [DownloadedBook] = []

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let book = try? decoder.decode(DownloadedBook.self, from: data) {
                books.append(book)
            }
        }

        return books
    }

    func deleteBookMetadata(bookId: String) async throws {
        let filePath = metadataDirectory.appendingPathComponent("\(bookId).json")
        if fileManager.fileExists(atPath: filePath.path) {
            try fileManager.removeItem(at: filePath)
        }
    }

    // MARK: - Cover Images

    func saveCover(_ imageData: Data, bookId: String) async throws -> String {
        let filePath = coversDirectory.appendingPathComponent("\(bookId).jpg")
        try imageData.write(to: filePath)
        return filePath.path
    }

    func loadCover(bookId: String) async -> Data? {
        let filePath = coversDirectory.appendingPathComponent("\(bookId).jpg")
        return fileManager.contents(atPath: filePath.path)
    }

    func coverPath(bookId: String) -> String {
        coversDirectory.appendingPathComponent("\(bookId).jpg").path
    }

    func hasCover(bookId: String) async -> Bool {
        let filePath = coversDirectory.appendingPathComponent("\(bookId).jpg")
        return fileManager.fileExists(atPath: filePath.path)
    }

    // MARK: - Delete Book Content

    func deleteBookContent(bookId: String) async throws {
        // Delete chapters
        let bookChaptersDir = chaptersDirectory.appendingPathComponent(bookId, isDirectory: true)
        if fileManager.fileExists(atPath: bookChaptersDir.path) {
            try fileManager.removeItem(at: bookChaptersDir)
        }

        // Delete cover
        let coverPath = coversDirectory.appendingPathComponent("\(bookId).jpg")
        if fileManager.fileExists(atPath: coverPath.path) {
            try fileManager.removeItem(at: coverPath)
        }

        // Delete metadata
        try await deleteBookMetadata(bookId: bookId)
    }

    // MARK: - Storage Info

    func getStorageInfo() async -> StorageInfo {
        let offlineSize = await calculateDirectorySize(offlineDirectory)
        let cacheSize = await calculateDirectorySize(cacheDirectory)

        let totalSpace = (try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemSize] as? Int64) ?? 0
        let freeSpace = (try? fileManager.attributesOfFileSystem(forPath: NSHomeDirectory())[.systemFreeSize] as? Int64) ?? 0

        return StorageInfo(
            totalSpace: totalSpace,
            usedSpace: totalSpace - freeSpace,
            availableSpace: freeSpace,
            offlineContentSize: offlineSize,
            cacheSize: cacheSize
        )
    }

    private func calculateDirectorySize(_ url: URL) async -> Int64 {
        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        var totalSize: Int64 = 0
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])

        while let fileURL = enumerator?.nextObject() as? URL {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(fileSize)
            }
        }

        return totalSize
    }

    // MARK: - Cache Management

    func clearCache() async throws {
        if fileManager.fileExists(atPath: cacheDirectory.path) {
            try fileManager.removeItem(at: cacheDirectory)
        }
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func clearAllOfflineContent() async throws {
        if fileManager.fileExists(atPath: offlineDirectory.path) {
            try fileManager.removeItem(at: offlineDirectory)
        }
        await ensureDirectoriesExist()
    }

    // MARK: - Temporary Cache

    func cacheData(_ data: Data, key: String) async throws {
        let filePath = cacheDirectory.appendingPathComponent(key)
        try data.write(to: filePath)
    }

    func getCachedData(key: String) async -> Data? {
        let filePath = cacheDirectory.appendingPathComponent(key)
        return fileManager.contents(atPath: filePath.path)
    }

    func removeCachedData(key: String) async throws {
        let filePath = cacheDirectory.appendingPathComponent(key)
        if fileManager.fileExists(atPath: filePath.path) {
            try fileManager.removeItem(at: filePath)
        }
    }

    // MARK: - Downloaded Chapters Index

    func getDownloadedChapterIds(bookId: String) async -> [String] {
        let bookDir = chaptersDirectory.appendingPathComponent(bookId, isDirectory: true)
        guard fileManager.fileExists(atPath: bookDir.path) else { return [] }

        do {
            let files = try fileManager.contentsOfDirectory(at: bookDir, includingPropertiesForKeys: nil)
            return files
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
        } catch {
            return []
        }
    }

    func getDownloadedChapterCount(bookId: String) async -> Int {
        await getDownloadedChapterIds(bookId: bookId).count
    }
}
