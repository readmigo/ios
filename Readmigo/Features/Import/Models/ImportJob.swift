import Foundation

/// Import job status
enum ImportJobStatus: String, Codable {
    case pending = "PENDING"
    case uploading = "UPLOADING"
    case processing = "PROCESSING"
    case completed = "COMPLETED"
    case failed = "FAILED"

    var displayName: String {
        switch self {
        case .pending: return "import.status.pending".localized
        case .uploading: return "import.status.uploading".localized
        case .processing: return "import.status.processing".localized
        case .completed: return "import.status.completed".localized
        case .failed: return "import.status.failed".localized
        }
    }
}

/// Import job model
struct ImportJob: Identifiable, Codable, Equatable {
    let id: String
    let filename: String
    let fileSize: Int
    let fileFormat: String
    var status: ImportJobStatus
    var progress: Int
    var book: ImportedBookSummary?
    var errorMessage: String?
    let createdAt: Date
    var completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case filename
        case fileSize = "file_size"
        case fileFormat = "file_format"
        case status
        case progress
        case book
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }

    /// Formatted file size
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

/// Summary of imported book (returned after processing)
struct ImportedBookSummary: Codable, Equatable {
    let id: String
    let title: String
    let author: String?
    let coverUrl: String?
    let chapterCount: Int
    let wordCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case coverUrl = "cover_url"
        case chapterCount = "chapter_count"
        case wordCount = "word_count"
    }
}

// MARK: - API Request/Response Models

/// Request to initiate import
struct InitiateImportRequest: Codable {
    let filename: String
    let fileSize: Int
    let contentType: String
    let md5: String?

    enum CodingKeys: String, CodingKey {
        case filename
        case fileSize = "file_size"
        case contentType = "content_type"
        case md5
    }
}

/// Response from initiate import
struct InitiateImportResponse: Codable {
    let jobId: String
    let uploadUrl: String
    let uploadKey: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case uploadUrl = "upload_url"
        case uploadKey = "upload_key"
        case expiresIn = "expires_in"
    }
}

/// Request to complete upload
struct CompleteUploadRequest: Codable {
    let jobId: String

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
    }
}

/// Response from complete upload
struct CompleteUploadResponse: Codable {
    let jobId: String
    let status: ImportJobStatus

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
    }
}

/// Response for job status query
struct JobStatusResponse: Codable {
    let jobId: String
    let status: ImportJobStatus
    let progress: Int
    let book: ImportedBookSummary?
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progress
        case book
        case errorMessage = "error_message"
    }
}
