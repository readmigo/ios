import Foundation

/// Provides clean plain-text paragraphs for TTS.
/// Priority: disk cache → /text API → HTML tag stripping (fallback).
@MainActor
class ChapterTextProvider {
    static let shared = ChapterTextProvider()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// In-memory cache keyed by "\(bookId)/\(chapterId)"
    private var memoryCache: [String: [ChapterParagraph]] = [:]

    private var cacheDirectory: URL {
        let dir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("tts-cache", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Public API

    /// Fetch plain-text paragraphs for a chapter.
    func fetchParagraphs(bookId: String, chapterId: String) async throws -> [ChapterParagraph] {
        let key = "\(bookId)/\(chapterId)"

        // 1. Memory cache
        if let cached = memoryCache[key] {
            return cached
        }

        // 2. Disk cache
        if let cached = loadFromDisk(bookId: bookId, chapterId: chapterId) {
            memoryCache[key] = cached
            return cached
        }

        // 3. /text API
        do {
            let response: ChapterTextResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.chapterText(bookId, chapterId)
            )
            let paragraphs = response.paragraphs
            saveToDisk(paragraphs, bookId: bookId, chapterId: chapterId)
            memoryCache[key] = paragraphs
            return paragraphs
        } catch {
            // 4. HTML fallback — strip tags from locally available content
            if let fallback = try? await htmlFallback(bookId: bookId, chapterId: chapterId) {
                memoryCache[key] = fallback
                return fallback
            }
            throw error
        }
    }

    /// Preload next chapter in background (fire-and-forget).
    func preloadNextChapter(bookId: String, chapterId: String) {
        Task {
            _ = try? await fetchParagraphs(bookId: bookId, chapterId: chapterId)
        }
    }

    /// Clear all cached text data.
    func clearCache() {
        memoryCache.removeAll()
        try? fileManager.removeItem(at: cacheDirectory)
    }

    // MARK: - Disk Cache

    private func cacheFileURL(bookId: String, chapterId: String) -> URL {
        let bookDir = cacheDirectory.appendingPathComponent(bookId, isDirectory: true)
        if !fileManager.fileExists(atPath: bookDir.path) {
            try? fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)
        }
        return bookDir.appendingPathComponent("\(chapterId).json")
    }

    private func loadFromDisk(bookId: String, chapterId: String) -> [ChapterParagraph]? {
        let url = cacheFileURL(bookId: bookId, chapterId: chapterId)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode([ChapterParagraph].self, from: data)
    }

    private func saveToDisk(_ paragraphs: [ChapterParagraph], bookId: String, chapterId: String) {
        let url = cacheFileURL(bookId: bookId, chapterId: chapterId)
        if let data = try? encoder.encode(paragraphs) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // MARK: - HTML Fallback

    /// Strip HTML tags from chapter content available via OfflineManager.
    private func htmlFallback(bookId: String, chapterId: String) async throws -> [ChapterParagraph] {
        let offlineManager = OfflineManager.shared
        if let content = await offlineManager.getOfflineChapterContent(bookId: bookId, chapterId: chapterId) {
            return extractParagraphsFromHTML(content.htmlContent)
        }

        throw NSError(domain: "ChapterTextProvider", code: 0,
                       userInfo: [NSLocalizedDescriptionKey: "No text source available offline"])
    }

    /// Regex-based HTML paragraph extraction (fallback only).
    private func extractParagraphsFromHTML(_ html: String) -> [ChapterParagraph] {
        var paragraphs: [ChapterParagraph] = []
        let pattern = "<p[^>]*>([\\s\\S]*?)</p>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return paragraphs
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard match.numberOfRanges > 1 else { continue }
            let inner = nsHTML.substring(with: match.range(at: 1))

            // Strip remaining tags and decode entities
            let text = inner
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .replacingOccurrences(of: "&nbsp;", with: " ")
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#?\\w+;", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                paragraphs.append(ChapterParagraph(index: paragraphs.count, text: text))
            }
        }
        return paragraphs
    }
}
