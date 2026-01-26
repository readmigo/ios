import Foundation

/// MOBI file metadata
struct MobiMetadata {
    let title: String
    let author: String
    let publisher: String
    let language: String
    let isbn: String
    let description: String
}

/// Parsed chapter from MOBI file
struct ParsedMobiChapter: Identifiable {
    let id: String
    let title: String
    let content: String
    let html: String
}

/// Parsed MOBI document
struct ParsedMobiDocument {
    let metadata: MobiMetadata
    let chapters: [ParsedMobiChapter]
    let html: String
    let css: String
}

/// MOBI file parser with support for PalmDOC compression
class MobiParser {

    // MARK: - Constants

    private static let palmDocCompressionNone: UInt16 = 1
    private static let palmDocCompressionPalmDoc: UInt16 = 2
    private static let palmDocCompressionHuffCDIC: UInt16 = 17480

    // MARK: - Data Structures

    private struct PalmHeader {
        let name: String
        let attributes: UInt16
        let version: UInt16
        let creationDate: UInt32
        let modificationDate: UInt32
        let numRecords: UInt16
    }

    private struct PalmDocHeader {
        let compression: UInt16
        let textLength: UInt32
        let recordCount: UInt16
        let recordSize: UInt16
        let encryptionType: UInt16
    }

    private struct MobiHeader {
        let identifier: String
        let headerLength: UInt32
        let mobiType: UInt32
        let textEncoding: UInt32
        let firstImageRecord: UInt32
        let fullTitle: String
        let author: String
        let publisher: String
        let language: String
        let isbn: String
        let description: String
        let exthFlags: UInt32
    }

    // MARK: - Parsing

    /// Parse MOBI file from data
    static func parse(data: Data) throws -> ParsedMobiDocument {
        guard data.count > 100 else {
            throw MobiParserError.invalidFile
        }

        // Parse Palm Database header
        let palmHeader = try parsePalmHeader(from: data)

        // Parse record offsets
        var recordOffsets: [UInt32] = []
        for i in 0..<Int(palmHeader.numRecords) {
            let offset = data.readUInt32(at: 78 + (i * 8))
            recordOffsets.append(offset)
        }

        guard !recordOffsets.isEmpty else {
            throw MobiParserError.noRecords
        }

        // First record contains PalmDOC header
        let record0Offset = Int(recordOffsets[0])
        let palmDocHeader = parsePalmDocHeader(from: data, offset: record0Offset)

        // Parse MOBI header
        let mobiHeader = parseMobiHeader(from: data, offset: record0Offset + 16)

        // Extract text content
        let textContent = extractTextContent(
            from: data,
            recordOffsets: recordOffsets,
            palmDocHeader: palmDocHeader,
            mobiHeader: mobiHeader
        )

        // Parse HTML content
        let (chapters, html, css) = parseHtmlContent(textContent, fallbackTitle: palmHeader.name)

        let metadata = MobiMetadata(
            title: mobiHeader.fullTitle.isEmpty ? palmHeader.name : mobiHeader.fullTitle,
            author: mobiHeader.author.isEmpty ? "Unknown" : mobiHeader.author,
            publisher: mobiHeader.publisher,
            language: mobiHeader.language.isEmpty ? "en" : mobiHeader.language,
            isbn: mobiHeader.isbn,
            description: mobiHeader.description
        )

        return ParsedMobiDocument(
            metadata: metadata,
            chapters: chapters,
            html: html,
            css: css
        )
    }

    /// Parse MOBI file from URL
    static func parse(url: URL) async throws -> ParsedMobiDocument {
        let data: Data

        if url.isFileURL {
            data = try Data(contentsOf: url)
        } else {
            let (downloadedData, _) = try await URLSession.shared.data(from: url)
            data = downloadedData
        }

        return try parse(data: data)
    }

    // MARK: - Header Parsing

    private static func parsePalmHeader(from data: Data) throws -> PalmHeader {
        // Name is 32 bytes at offset 0
        let nameData = data.subdata(in: 0..<32)
        let name = String(data: nameData, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? ""

        return PalmHeader(
            name: name,
            attributes: data.readUInt16(at: 32),
            version: data.readUInt16(at: 34),
            creationDate: data.readUInt32(at: 36),
            modificationDate: data.readUInt32(at: 40),
            numRecords: data.readUInt16(at: 76)
        )
    }

    private static func parsePalmDocHeader(from data: Data, offset: Int) -> PalmDocHeader {
        return PalmDocHeader(
            compression: data.readUInt16(at: offset),
            textLength: data.readUInt32(at: offset + 4),
            recordCount: data.readUInt16(at: offset + 8),
            recordSize: data.readUInt16(at: offset + 10),
            encryptionType: data.readUInt16(at: offset + 12)
        )
    }

    private static func parseMobiHeader(from data: Data, offset: Int) -> MobiHeader {
        // Check for MOBI identifier
        guard offset + 4 <= data.count else {
            return emptyMobiHeader()
        }

        let identData = data.subdata(in: offset..<(offset + 4))
        let identifier = String(data: identData, encoding: .ascii) ?? ""

        guard identifier == "MOBI" else {
            return emptyMobiHeader()
        }

        let headerLength = data.readUInt32(at: offset + 4)
        let mobiType = data.readUInt32(at: offset + 8)
        let textEncoding = data.readUInt32(at: offset + 12)

        var firstImageRecord: UInt32 = 0
        var exthFlags: UInt32 = 0
        var fullTitle = ""

        if offset + 112 <= data.count {
            firstImageRecord = data.readUInt32(at: offset + 108)
        }

        if offset + 132 <= data.count {
            exthFlags = data.readUInt32(at: offset + 128)
        }

        // Get full title
        if offset + 92 <= data.count {
            let fullNameOffset = data.readUInt32(at: offset + 84)
            let fullNameLength = data.readUInt32(at: offset + 88)

            if fullNameOffset > 0 && fullNameLength > 0 {
                let titleStart = offset - 16 + Int(fullNameOffset)
                let titleEnd = titleStart + Int(fullNameLength)

                if titleStart >= 0 && titleEnd <= data.count {
                    let titleData = data.subdata(in: titleStart..<titleEnd)
                    fullTitle = String(data: titleData, encoding: .utf8) ?? ""
                }
            }
        }

        // Parse EXTH header if present
        var author = ""
        var publisher = ""
        var description = ""
        var isbn = ""
        var language = "en"

        if exthFlags & 0x40 != 0 {
            let exthOffset = offset + Int(headerLength)
            let exthData = parseExthHeader(from: data, offset: exthOffset)
            author = exthData.author
            publisher = exthData.publisher
            description = exthData.description
            isbn = exthData.isbn
            language = exthData.language.isEmpty ? "en" : exthData.language
        }

        return MobiHeader(
            identifier: identifier,
            headerLength: headerLength,
            mobiType: mobiType,
            textEncoding: textEncoding,
            firstImageRecord: firstImageRecord,
            fullTitle: fullTitle,
            author: author,
            publisher: publisher,
            language: language,
            isbn: isbn,
            description: description,
            exthFlags: exthFlags
        )
    }

    private static func emptyMobiHeader() -> MobiHeader {
        return MobiHeader(
            identifier: "",
            headerLength: 0,
            mobiType: 0,
            textEncoding: 65001,
            firstImageRecord: 0,
            fullTitle: "",
            author: "",
            publisher: "",
            language: "en",
            isbn: "",
            description: "",
            exthFlags: 0
        )
    }

    private static func parseExthHeader(from data: Data, offset: Int) -> (author: String, publisher: String, description: String, isbn: String, language: String) {
        var author = ""
        var publisher = ""
        var description = ""
        var isbn = ""
        var language = ""

        guard offset + 12 <= data.count else {
            return (author, publisher, description, isbn, language)
        }

        let identData = data.subdata(in: offset..<(offset + 4))
        let identifier = String(data: identData, encoding: .ascii) ?? ""

        guard identifier == "EXTH" else {
            return (author, publisher, description, isbn, language)
        }

        let recordCount = data.readUInt32(at: offset + 8)
        var recordOffset = offset + 12

        for _ in 0..<recordCount {
            guard recordOffset + 8 <= data.count else { break }

            let recordType = data.readUInt32(at: recordOffset)
            let recordLength = data.readUInt32(at: recordOffset + 4)
            let dataLength = Int(recordLength) - 8

            if dataLength > 0 && recordOffset + 8 + dataLength <= data.count {
                let valueData = data.subdata(in: (recordOffset + 8)..<(recordOffset + 8 + dataLength))
                let value = String(data: valueData, encoding: .utf8) ?? ""

                switch recordType {
                case 100:
                    author = value
                case 101:
                    publisher = value
                case 103:
                    description = value
                case 104:
                    isbn = value
                case 524:
                    language = value
                default:
                    break
                }
            }

            recordOffset += Int(recordLength)
        }

        return (author, publisher, description, isbn, language)
    }

    // MARK: - Text Extraction

    private static func extractTextContent(
        from data: Data,
        recordOffsets: [UInt32],
        palmDocHeader: PalmDocHeader,
        mobiHeader: MobiHeader
    ) -> String {
        var textRecords: [Data] = []
        let startRecord = 1
        let endRecord = min(Int(palmDocHeader.recordCount) + 1, recordOffsets.count - 1)

        for i in startRecord...endRecord {
            guard i < recordOffsets.count else { break }

            let recordStart = Int(recordOffsets[i])
            let recordEnd: Int

            if i < recordOffsets.count - 1 {
                recordEnd = Int(recordOffsets[i + 1])
            } else {
                recordEnd = data.count
            }

            guard recordStart < recordEnd && recordEnd <= data.count else { continue }

            let recordData = data.subdata(in: recordStart..<recordEnd)
            let decompressed: Data

            switch palmDocHeader.compression {
            case palmDocCompressionNone:
                decompressed = recordData
            case palmDocCompressionPalmDoc:
                decompressed = decompressPalmDoc(recordData)
            default:
                decompressed = recordData
            }

            textRecords.append(decompressed)
        }

        // Combine all records
        var combined = Data()
        for record in textRecords {
            combined.append(record)
        }

        // Decode based on text encoding
        let encoding: String.Encoding = mobiHeader.textEncoding == 1252 ? .windowsCP1252 : .utf8
        return String(data: combined, encoding: encoding) ?? String(data: combined, encoding: .utf8) ?? ""
    }

    /// PalmDOC decompression algorithm
    private static func decompressPalmDoc(_ data: Data) -> Data {
        var output = Data()
        let bytes = [UInt8](data)
        var i = 0

        while i < bytes.count {
            let byte = bytes[i]

            if byte == 0 {
                output.append(0)
                i += 1
            } else if byte >= 1 && byte <= 8 {
                // Literal bytes follow
                for j in 0..<Int(byte) {
                    if i + 1 + j < bytes.count {
                        output.append(bytes[i + 1 + j])
                    }
                }
                i += Int(byte) + 1
            } else if byte >= 9 && byte <= 0x7F {
                output.append(byte)
                i += 1
            } else if byte >= 0x80 && byte <= 0xBF {
                // Distance-length pair
                guard i + 1 < bytes.count else { break }

                let nextByte = bytes[i + 1]
                let distance = Int((UInt16(byte & 0x3F) << 8 | UInt16(nextByte)) >> 3)
                let length = Int(nextByte & 0x07) + 3

                for _ in 0..<length {
                    let srcIndex = output.count - distance
                    if srcIndex >= 0 && srcIndex < output.count {
                        output.append(output[srcIndex])
                    }
                }
                i += 2
            } else if byte >= 0xC0 && byte <= 0xFF {
                // Space + character
                output.append(0x20)
                output.append(byte ^ 0x80)
                i += 1
            } else {
                i += 1
            }
        }

        return output
    }

    // MARK: - HTML Parsing

    private static func parseHtmlContent(_ rawContent: String, fallbackTitle: String) -> (chapters: [ParsedMobiChapter], html: String, css: String) {
        // Clean up the content
        var html = rawContent

        // Remove null bytes and control characters
        html = html.replacingOccurrences(of: "[\u{0000}-\u{0008}\u{000B}\u{000C}\u{000E}-\u{001F}]", with: "", options: .regularExpression)

        // Extract CSS
        var css = ""
        let stylePattern = try? NSRegularExpression(pattern: "<style[^>]*>([\\s\\S]*?)</style>", options: .caseInsensitive)
        if let pattern = stylePattern {
            let range = NSRange(html.startIndex..., in: html)
            let matches = pattern.matches(in: html, options: [], range: range)

            for match in matches {
                if let cssRange = Range(match.range(at: 1), in: html) {
                    css += String(html[cssRange]) + "\n"
                }
            }
        }

        // Parse chapters from HTML structure
        var chapters: [ParsedMobiChapter] = []

        // Try to find chapter markers
        let chapterPatterns = [
            "<h[12][^>]*>([^<]+)</h[12]>",
            "<p[^>]*class=\"[^\"]*chapter[^\"]*\"[^>]*>([^<]+)</p>"
        ]

        var chapterMarkers: [(index: Int, title: String)] = []

        for patternString in chapterPatterns {
            guard let pattern = try? NSRegularExpression(pattern: patternString, options: .caseInsensitive) else { continue }

            let range = NSRange(html.startIndex..., in: html)
            let matches = pattern.matches(in: html, options: [], range: range)

            for match in matches {
                if let titleRange = Range(match.range(at: 1), in: html) {
                    let title = String(html[titleRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty && title.count < 200 {
                        let index = match.range.location
                        chapterMarkers.append((index: index, title: cleanHtmlText(title)))
                    }
                }
            }
        }

        // Sort by position and remove duplicates
        chapterMarkers.sort { $0.index < $1.index }
        let uniqueMarkers = chapterMarkers.enumerated().filter { i, marker in
            i == 0 || marker.index - chapterMarkers[i - 1].index > 100
        }.map { $0.element }

        if !uniqueMarkers.isEmpty {
            for (i, marker) in uniqueMarkers.enumerated() {
                let startIndex = html.index(html.startIndex, offsetBy: marker.index, limitedBy: html.endIndex) ?? html.endIndex
                let endIndex: String.Index

                if i < uniqueMarkers.count - 1 {
                    endIndex = html.index(html.startIndex, offsetBy: uniqueMarkers[i + 1].index, limitedBy: html.endIndex) ?? html.endIndex
                } else {
                    endIndex = html.endIndex
                }

                let chapterHtml = String(html[startIndex..<endIndex])

                chapters.append(ParsedMobiChapter(
                    id: "chapter-\(i)",
                    title: marker.title,
                    content: cleanHtmlText(chapterHtml),
                    html: chapterHtml
                ))
            }
        } else {
            // No chapters found, create single chapter
            chapters.append(ParsedMobiChapter(
                id: "chapter-0",
                title: fallbackTitle.isEmpty ? "Content" : fallbackTitle,
                content: cleanHtmlText(html),
                html: html
            ))
        }

        return (chapters, html, css)
    }

    private static func cleanHtmlText(_ html: String) -> String {
        var text = html

        // Remove HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")

        // Clean up whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Validation

    /// Check if data is a valid MOBI file
    static func isMobiFile(_ data: Data) -> Bool {
        guard data.count >= 100 else { return false }

        // Check for Palm Database signature at offset 60-67
        let typeData = data.subdata(in: 60..<64)
        let creatorData = data.subdata(in: 64..<68)

        let type = String(data: typeData, encoding: .ascii) ?? ""
        let creator = String(data: creatorData, encoding: .ascii) ?? ""

        return (type == "BOOK" && creator == "MOBI") || (type == "TEXt" && creator == "REAd")
    }
}

// MARK: - Error Types

enum MobiParserError: Error, LocalizedError {
    case invalidFile
    case noRecords
    case decompressionFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            return "Invalid MOBI file format"
        case .noRecords:
            return "No records found in file"
        case .decompressionFailed:
            return "Failed to decompress content"
        case .encodingFailed:
            return "Failed to decode text content"
        }
    }
}

// MARK: - Data Extensions

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt16.self).bigEndian
        }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }
}
