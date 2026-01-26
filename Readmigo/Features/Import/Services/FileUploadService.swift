import Foundation

/// Service for handling file uploads to presigned URLs
class FileUploadService: NSObject {
    static let shared = FileUploadService()

    private var uploadTasks: [String: URLSessionUploadTask] = [:]
    private var progressHandlers: [String: (Double) -> Void] = [:]
    private var completionHandlers: [String: (Result<Void, Error>) -> Void] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5 minutes for large files
        config.timeoutIntervalForResource = 600 // 10 minutes total
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    private override init() {
        super.init()
    }

    // MARK: - Upload Methods

    /// Upload a file to a presigned URL with progress tracking
    /// - Parameters:
    ///   - fileURL: Local file URL
    ///   - presignedURL: Presigned upload URL from backend
    ///   - contentType: MIME type of the file
    ///   - progress: Progress callback (0.0 - 1.0)
    /// - Returns: Void on success, throws on error
    func uploadFile(
        from fileURL: URL,
        to presignedURL: String,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        // Read file data
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ImportError.uploadFailed("File not found")
        }

        let fileData = try Data(contentsOf: fileURL)
        return try await uploadData(fileData, to: presignedURL, contentType: contentType, progress: progress)
    }

    /// Upload data to a presigned URL with progress tracking
    /// - Parameters:
    ///   - data: Data to upload
    ///   - presignedURL: Presigned upload URL from backend
    ///   - contentType: MIME type of the file
    ///   - progress: Progress callback (0.0 - 1.0)
    func uploadData(
        _ data: Data,
        to presignedURL: String,
        contentType: String,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let url = URL(string: presignedURL) else {
            throw ImportError.uploadFailed("Invalid upload URL")
        }

        let taskId = UUID().uuidString

        return try await withCheckedThrowingContinuation { continuation in
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")

            let task = session.uploadTask(with: request, from: data)

            // Store handlers
            progressHandlers[taskId] = progress
            completionHandlers[taskId] = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Store task for tracking
            uploadTasks[taskId] = task
            task.taskDescription = taskId

            task.resume()
        }
    }

    // MARK: - Task Management

    /// Cancel an upload
    func cancelUpload(taskId: String) {
        uploadTasks[taskId]?.cancel()
        cleanupTask(taskId: taskId)
    }

    /// Cancel all uploads
    func cancelAllUploads() {
        for (taskId, task) in uploadTasks {
            task.cancel()
            cleanupTask(taskId: taskId)
        }
    }

    private func cleanupTask(taskId: String) {
        uploadTasks.removeValue(forKey: taskId)
        progressHandlers.removeValue(forKey: taskId)
        completionHandlers.removeValue(forKey: taskId)
    }
}

// MARK: - URLSessionTaskDelegate

extension FileUploadService: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard let taskId = task.taskDescription else { return }

        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressHandlers[taskId]?(progress)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let taskId = task.taskDescription else { return }

        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                completionHandlers[taskId]?(.failure(ImportError.cancelled))
            } else {
                completionHandlers[taskId]?(.failure(ImportError.uploadFailed(error.localizedDescription)))
            }
        } else if let httpResponse = task.response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
                completionHandlers[taskId]?(.success(()))
            } else {
                completionHandlers[taskId]?(.failure(ImportError.uploadFailed("Server returned status \(httpResponse.statusCode)")))
            }
        } else {
            completionHandlers[taskId]?(.failure(ImportError.uploadFailed("Unknown error")))
        }

        cleanupTask(taskId: taskId)
    }
}

// MARK: - File Helpers

extension URL {
    /// Get file size in bytes
    var fileSize: Int? {
        do {
            let resourceValues = try resourceValues(forKeys: [.fileSizeKey])
            return resourceValues.fileSize
        } catch {
            return nil
        }
    }

    /// Get MIME type based on file extension
    var mimeType: String {
        let ext = pathExtension.lowercased()
        switch ext {
        case "epub":
            return "application/epub+zip"
        case "txt":
            return "text/plain"
        case "pdf":
            return "application/pdf"
        case "mobi":
            return "application/x-mobipocket-ebook"
        case "azw", "azw3":
            return "application/vnd.amazon.ebook"
        default:
            return "application/octet-stream"
        }
    }

    /// Calculate MD5 hash of file
    func md5Hash() -> String? {
        guard let data = try? Data(contentsOf: self) else { return nil }
        return data.md5Hash()
    }
}

extension Data {
    /// Calculate MD5 hash
    func md5Hash() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = withUnsafeBytes {
            CC_MD5($0.baseAddress, CC_LONG(count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

import CommonCrypto
