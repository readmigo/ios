import Foundation

/// Service for handling book import API calls
@MainActor
class ImportService: ObservableObject {
    static let shared = ImportService()

    /// Cached quota (refreshed periodically)
    @Published private(set) var quota: ImportQuota?

    /// Active import jobs
    @Published private(set) var activeJobs: [ImportJob] = []

    private init() {}

    // MARK: - Quota

    /// Fetch user's import quota
    func fetchQuota() async throws -> ImportQuota {
        let response: ImportQuota = try await APIClient.shared.request(
            endpoint: APIEndpoints.userBooksQuota,
            method: .get
        )
        quota = response
        return response
    }

    // MARK: - Import Flow

    /// Step 1: Initiate import and get presigned URL
    /// - Parameters:
    ///   - filename: Original filename
    ///   - fileSize: File size in bytes
    ///   - contentType: MIME type of the file
    ///   - md5: Optional MD5 hash for integrity check
    /// - Returns: InitiateImportResponse with upload URL
    func initiateImport(
        filename: String,
        fileSize: Int,
        contentType: String,
        md5: String? = nil
    ) async throws -> InitiateImportResponse {
        let request = InitiateImportRequest(
            filename: filename,
            fileSize: fileSize,
            contentType: contentType,
            md5: md5
        )

        let response: InitiateImportResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.userBooksImportInitiate,
            method: .post,
            body: request
        )

        return response
    }

    /// Step 2: Confirm upload completed
    /// - Parameter jobId: Import job ID
    /// - Returns: CompleteUploadResponse with processing status
    func completeUpload(jobId: String) async throws -> CompleteUploadResponse {
        let request = CompleteUploadRequest(jobId: jobId)

        let response: CompleteUploadResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.userBooksImportComplete,
            method: .post,
            body: request
        )

        return response
    }

    /// Step 3: Poll job status
    /// - Parameter jobId: Import job ID
    /// - Returns: Current job status
    func getJobStatus(jobId: String) async throws -> JobStatusResponse {
        let response: JobStatusResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.userBooksImportStatus(jobId),
            method: .get
        )

        return response
    }

    // MARK: - User Imported Books

    /// Fetch list of user's imported books
    func fetchImportedBooks(page: Int = 1, limit: Int = 20) async throws -> ImportedBooksResponse {
        let response: ImportedBooksResponse = try await APIClient.shared.request(
            endpoint: "\(APIEndpoints.userBooks)?source=imported&page=\(page)&limit=\(limit)",
            method: .get
        )

        return response
    }

    /// Delete an imported book
    /// - Parameter bookId: Book ID to delete
    func deleteImportedBook(bookId: String) async throws {
        let _: SuccessResponse = try await APIClient.shared.request(
            endpoint: APIEndpoints.userBooksImported(bookId),
            method: .delete
        )

        // Refresh quota after deletion
        _ = try? await fetchQuota()
    }

    // MARK: - Active Job Tracking

    /// Add a job to active tracking
    func trackJob(_ job: ImportJob) {
        if !activeJobs.contains(where: { $0.id == job.id }) {
            activeJobs.append(job)
        }
    }

    /// Update a tracked job's status
    func updateJob(_ jobId: String, status: ImportJobStatus, progress: Int, book: ImportedBookSummary? = nil, error: String? = nil) {
        if let index = activeJobs.firstIndex(where: { $0.id == jobId }) {
            activeJobs[index].status = status
            activeJobs[index].progress = progress
            activeJobs[index].book = book
            activeJobs[index].errorMessage = error
            if status == .completed || status == .failed {
                activeJobs[index].completedAt = Date()
            }
        }
    }

    /// Remove a job from active tracking
    func removeJob(_ jobId: String) {
        activeJobs.removeAll { $0.id == jobId }
    }

    /// Clear all completed/failed jobs
    func clearCompletedJobs() {
        activeJobs.removeAll { $0.status == .completed || $0.status == .failed }
    }
}

// MARK: - Response Models

/// Response for imported books list
struct ImportedBooksResponse: Codable {
    let items: [ImportedBookItem]
    let total: Int
    let page: Int
    let limit: Int
}

/// Single imported book item
struct ImportedBookItem: Identifiable, Codable, Equatable {
    let id: String
    let book: ImportedBookDetail
    let importedAt: Date
    let originalFilename: String
    let fileSize: Int

    enum CodingKeys: String, CodingKey {
        case id
        case book
        case importedAt = "imported_at"
        case originalFilename = "original_filename"
        case fileSize = "file_size"
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

/// Imported book details
struct ImportedBookDetail: Codable, Equatable {
    let id: String
    let title: String
    let author: String?
    let coverUrl: String?
    let wordCount: Int?
    let chapterCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case coverUrl = "cover_url"
        case wordCount = "word_count"
        case chapterCount = "chapter_count"
    }
}
