import SwiftUI
import PhotosUI

/// Attachment picker component for selecting and managing image attachments
struct AttachmentPickerView: View {
    @Binding var attachments: [PendingAttachment]
    let maxAttachments: Int
    let onAddImage: (UIImage) -> Void
    let onRemoveAttachment: (String) -> Void

    @State private var showingImagePicker = false
    @State private var showingActionSheet = false
    @State private var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedItems: [PhotosPickerItem] = []

    var canAddMore: Bool {
        attachments.count < maxAttachments
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("messaging.attachments".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Add button
                    if canAddMore {
                        PhotosPicker(selection: $selectedItems, maxSelectionCount: maxAttachments - attachments.count, matching: .images) {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("messaging.addPhoto".localized)
                                    .font(.caption)
                            }
                            .foregroundColor(.accentColor)
                            .frame(width: 80, height: 80)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        .onChange(of: selectedItems) { _, newItems in
                            Task {
                                for item in newItems {
                                    if let data = try? await item.loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                        onAddImage(image)
                                    }
                                }
                                selectedItems = []
                            }
                        }
                    }

                    // Existing attachments
                    ForEach(attachments) { attachment in
                        ZStack(alignment: .topTrailing) {
                            if let image = attachment.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .cornerRadius(8)
                                    .clipped()
                            }

                            // Remove button
                            Button {
                                onRemoveAttachment(attachment.id)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .offset(x: 8, y: -8)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Attachment count
            Text("\(attachments.count)/\(maxAttachments)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
