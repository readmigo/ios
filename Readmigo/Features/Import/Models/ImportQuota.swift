import Foundation

/// User import quota information
struct ImportQuota: Codable, Equatable {
    let used: QuotaUsage
    let limit: QuotaLimit
    let available: QuotaAvailable

    /// Check if user has remaining book quota
    var hasBookQuota: Bool {
        available.bookCount > 0
    }

    /// Check if user has remaining storage quota
    var hasStorageQuota: Bool {
        available.totalSizeBytes > 0
    }

    /// Check if user can import a file of given size
    func canImport(fileSize: Int) -> Bool {
        hasBookQuota && Int64(fileSize) <= available.totalSizeBytes
    }

    /// Usage percentage (0.0 - 1.0)
    var usagePercentage: Double {
        guard limit.totalSizeBytes > 0 else { return 0 }
        return Double(used.totalSizeBytes) / Double(limit.totalSizeBytes)
    }
}

/// Quota usage stats
struct QuotaUsage: Codable, Equatable {
    let bookCount: Int
    let totalSizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case bookCount = "book_count"
        case totalSizeBytes = "total_size_bytes"
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}

/// Quota limits
struct QuotaLimit: Codable, Equatable {
    let bookCount: Int
    let totalSizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case bookCount = "book_count"
        case totalSizeBytes = "total_size_bytes"
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}

/// Available quota
struct QuotaAvailable: Codable, Equatable {
    let bookCount: Int
    let totalSizeBytes: Int64

    enum CodingKeys: String, CodingKey {
        case bookCount = "book_count"
        case totalSizeBytes = "total_size_bytes"
    }

    /// Formatted size string
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}

// MARK: - Supported File Formats

/// Supported import file formats
enum ImportFileFormat: String, CaseIterable {
    case epub
    case txt
    case pdf

    /// MIME types for this format
    var mimeTypes: [String] {
        switch self {
        case .epub: return ["application/epub+zip", "application/octet-stream"]
        case .txt: return ["text/plain"]
        case .pdf: return ["application/pdf"]
        }
    }

    /// File extensions
    var extensions: [String] {
        switch self {
        case .epub: return ["epub"]
        case .txt: return ["txt"]
        case .pdf: return ["pdf"]
        }
    }

    /// Display name
    var displayName: String {
        rawValue.uppercased()
    }

    /// Check if a filename matches this format
    func matches(filename: String) -> Bool {
        let ext = (filename as NSString).pathExtension.lowercased()
        return extensions.contains(ext)
    }

    /// Get format from filename
    static func from(filename: String) -> ImportFileFormat? {
        let ext = (filename as NSString).pathExtension.lowercased()
        return allCases.first { $0.extensions.contains(ext) }
    }

    /// UTType identifiers for document picker
    var utTypes: [String] {
        switch self {
        case .epub: return ["org.idpf.epub-container", "public.epub"]
        case .txt: return ["public.plain-text"]
        case .pdf: return ["com.adobe.pdf"]
        }
    }
}

// MARK: - Import Errors

/// Import-specific errors
enum ImportError: Error, LocalizedError {
    case notSubscribed
    case quotaExceeded
    case invalidFormat(String)
    case fileTooLarge(Int64)
    case uploadFailed(String)
    case processingFailed(String)
    case networkError(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notSubscribed:
            return "import.error.notSubscribed".localized
        case .quotaExceeded:
            return "import.error.quotaExceeded".localized
        case .invalidFormat(let format):
            return String(format: "import.error.invalidFormat".localized, format)
        case .fileTooLarge(let maxSize):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            let sizeStr = formatter.string(fromByteCount: maxSize)
            return String(format: "import.error.fileTooLarge".localized, sizeStr)
        case .uploadFailed(let reason):
            return String(format: "import.error.uploadFailed".localized, reason)
        case .processingFailed(let reason):
            return String(format: "import.error.processingFailed".localized, reason)
        case .networkError(let reason):
            return String(format: "import.error.networkError".localized, reason)
        case .cancelled:
            return "import.error.cancelled".localized
        }
    }
}
