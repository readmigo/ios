import Foundation

/// Parsed chapter from TXT file
struct ParsedChapter: Identifiable {
    let id: String
    let title: String
    let content: String
    let paragraphs: [String]
    let startIndex: Int
    let endIndex: Int
}

/// Parsed TXT document
struct ParsedTxtDocument {
    let title: String
    let chapters: [ParsedChapter]
    let totalCharacters: Int
    let rawContent: String
}

/// TXT file parser with chapter detection
class TxtParser {

    // MARK: - Chapter Detection Patterns

    private static let chapterPatterns: [NSRegularExpression] = {
        let patterns = [
            // English patterns
            "^Chapter\\s+(\\d+|[IVXLC]+)(?:\\s*[:\\-–—.]\\s*(.*))?$",
            "^CHAPTER\\s+(\\d+|[IVXLC]+)(?:\\s*[:\\-–—.]\\s*(.*))?$",
            "^Part\\s+(\\d+|[IVXLC]+)(?:\\s*[:\\-–—.]\\s*(.*))?$",
            "^Book\\s+(\\d+|[IVXLC]+)(?:\\s*[:\\-–—.]\\s*(.*))?$",
            "^Section\\s+(\\d+)(?:\\s*[:\\-–—.]\\s*(.*))?$",
            // Chinese patterns
            "^第\\s*([零一二三四五六七八九十百千万\\d]+)\\s*章(?:\\s*[:\\-–—.：]\\s*(.*))?$",
            "^第\\s*([零一二三四五六七八九十百千万\\d]+)\\s*节(?:\\s*[:\\-–—.：]\\s*(.*))?$",
            "^第\\s*([零一二三四五六七八九十百千万\\d]+)\\s*卷(?:\\s*[:\\-–—.：]\\s*(.*))?$",
            "^第\\s*([零一二三四五六七八九十百千万\\d]+)\\s*回(?:\\s*[:\\-–—.：]\\s*(.*))?$",
            // Numbered patterns
            "^(\\d+)[\\.)\\s]\\s+(.+)$"
        ]

        return patterns.compactMap { pattern in
            try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines, .caseInsensitive])
        }
    }()

    // MARK: - Encoding Detection

    /// Detect text encoding from data
    static func detectEncoding(from data: Data) -> String.Encoding {
        // Check for BOM
        if data.count >= 3 {
            let bytes = [UInt8](data.prefix(3))
            if bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF {
                return .utf8
            }
        }

        if data.count >= 2 {
            let bytes = [UInt8](data.prefix(2))
            if bytes[0] == 0xFF && bytes[1] == 0xFE {
                return .utf16LittleEndian
            }
            if bytes[0] == 0xFE && bytes[1] == 0xFF {
                return .utf16BigEndian
            }
        }

        // Try UTF-8 first
        if String(data: data, encoding: .utf8) != nil {
            return .utf8
        }

        // Try common Chinese encodings
        let encodings: [String.Encoding] = [
            .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))),
            .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.big5.rawValue))),
            .isoLatin1
        ]

        for encoding in encodings {
            if String(data: data, encoding: encoding) != nil {
                return encoding
            }
        }

        return .utf8
    }

    /// Decode text from data with auto-detection
    static func decodeText(from data: Data, encoding: String.Encoding? = nil) -> String? {
        let detectedEncoding = encoding ?? detectEncoding(from: data)
        return String(data: data, encoding: detectedEncoding)
    }

    // MARK: - Chapter Detection

    /// Check if a line is a chapter heading
    private static func isChapterHeading(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }

        for pattern in chapterPatterns {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if pattern.firstMatch(in: trimmed, options: [], range: range) != nil {
                return true
            }
        }

        return false
    }

    /// Detect chapters in text content
    static func detectChapters(in content: String) -> [ParsedChapter] {
        let lines = content.components(separatedBy: .newlines)
        var chapters: [ParsedChapter] = []
        var currentChapter: (title: String, content: String, startIndex: Int)? = nil
        var chapterIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if var chapter = currentChapter {
                    chapter.content += "\n"
                    currentChapter = chapter
                }
                continue
            }

            if isChapterHeading(trimmed) {
                // Save previous chapter
                if let chapter = currentChapter {
                    let paragraphs = parseParagraphs(from: chapter.content)
                    chapters.append(ParsedChapter(
                        id: "chapter-\(chapters.count)",
                        title: chapter.title,
                        content: chapter.content,
                        paragraphs: paragraphs,
                        startIndex: chapter.startIndex,
                        endIndex: index - 1
                    ))
                }

                // Start new chapter
                currentChapter = (title: trimmed, content: "", startIndex: index)
                chapterIndex += 1
            } else if var chapter = currentChapter {
                chapter.content += trimmed + "\n"
                currentChapter = chapter
            } else {
                // Content before first chapter - create prologue
                currentChapter = (title: "Prologue", content: trimmed + "\n", startIndex: 0)
                chapterIndex = 1
            }
        }

        // Add last chapter
        if let chapter = currentChapter {
            let paragraphs = parseParagraphs(from: chapter.content)
            chapters.append(ParsedChapter(
                id: "chapter-\(chapters.count)",
                title: chapter.title,
                content: chapter.content,
                paragraphs: paragraphs,
                startIndex: chapter.startIndex,
                endIndex: lines.count - 1
            ))
        }

        // If no chapters detected, treat entire content as one chapter
        if chapters.isEmpty {
            let paragraphs = parseParagraphs(from: content)
            chapters.append(ParsedChapter(
                id: "chapter-0",
                title: "Chapter 1",
                content: content,
                paragraphs: paragraphs,
                startIndex: 0,
                endIndex: lines.count - 1
            ))
        }

        return chapters
    }

    /// Parse content into paragraphs
    private static func parseParagraphs(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var paragraphs: [String] = []
        var currentParagraph = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = ""
                }
            } else {
                // Check if this looks like a new paragraph
                let isNewParagraph = line.hasPrefix(" ") || line.hasPrefix("\t") ||
                    trimmed.hasPrefix(""") || trimmed.hasPrefix("\"") ||
                    trimmed.hasPrefix("「") || trimmed.hasPrefix("『")

                if isNewParagraph && !currentParagraph.isEmpty {
                    paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
                    currentParagraph = trimmed
                } else {
                    currentParagraph += (currentParagraph.isEmpty ? "" : " ") + trimmed
                }
            }
        }

        if !currentParagraph.isEmpty {
            paragraphs.append(currentParagraph.trimmingCharacters(in: .whitespaces))
        }

        return paragraphs.filter { !$0.isEmpty }
    }

    // MARK: - Parsing

    /// Extract title from filename or content
    private static func extractTitle(from filename: String?, content: String) -> String {
        if let filename = filename {
            let name = (filename as NSString).deletingPathExtension
            if !name.isEmpty {
                return name
            }
        }

        // Try to get title from first non-empty line
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && trimmed.count < 100 {
                return trimmed
            }
        }

        return "Untitled Document"
    }

    /// Parse TXT content
    static func parse(content: String, filename: String? = nil) -> ParsedTxtDocument {
        let chapters = detectChapters(in: content)
        let title = extractTitle(from: filename, content: content)

        return ParsedTxtDocument(
            title: title,
            chapters: chapters,
            totalCharacters: content.count,
            rawContent: content
        )
    }

    /// Parse TXT file from data
    static func parse(data: Data, filename: String? = nil, encoding: String.Encoding? = nil) -> ParsedTxtDocument? {
        guard let content = decodeText(from: data, encoding: encoding) else {
            return nil
        }
        return parse(content: content, filename: filename)
    }

    /// Parse TXT file from URL
    static func parse(url: URL) async throws -> ParsedTxtDocument {
        let data: Data

        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            let (downloadedData, _) = try await URLSession.shared.data(from: url)
            data = downloadedData
        }

        guard let document = parse(data: data, filename: url.lastPathComponent) else {
            throw NSError(domain: "TxtParser", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse TXT file"
            ])
        }

        return document
    }
}
