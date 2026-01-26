import Foundation

/// Attachment model for messages
struct Attachment: Identifiable, Codable, Equatable {
    let id: String
    let type: AttachmentType
    let url: String
    let thumbnailUrl: String?
    let fileName: String?
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case url
        case thumbnailUrl = "thumbnail_url"
        case fileName = "file_name"
        case fileSize = "file_size"
    }

    /// Attachment type
    enum AttachmentType: String, Codable {
        case image = "image"
        case file = "file"
    }

    /// Formatted file size string
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// Check if attachment is an image
    var isImage: Bool {
        type == .image
    }
}

/// Response for attachment upload
struct AttachmentUploadResponse: Codable {
    let attachment: Attachment
}
