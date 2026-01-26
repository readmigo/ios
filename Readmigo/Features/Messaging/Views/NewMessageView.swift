import SwiftUI

/// View for creating a new message
struct NewMessageView: View {
    @StateObject private var viewModel = NewMessageViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    let onSuccess: (MessageThread) -> Void

    enum Field {
        case subject
        case content
    }

    var body: some View {
        NavigationStack {
            Form {
                // Message Type Section
                Section {
                    MessageTypePickerView(selectedType: $viewModel.selectedType)
                } header: {
                    Text("messaging.messageType".localized)
                }

                // Subject Section
                Section {
                    TextField("messaging.subjectPlaceholder".localized, text: $viewModel.subject)
                        .focused($focusedField, equals: .subject)
                } header: {
                    Text("messaging.subject".localized)
                }

                // Content Section
                Section {
                    ZStack(alignment: .topLeading) {
                        if viewModel.content.isEmpty {
                            Text("messaging.contentPlaceholder".localized)
                                .foregroundColor(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }

                        TextEditor(text: $viewModel.content)
                            .focused($focusedField, equals: .content)
                            .frame(minHeight: 150)
                            .opacity(viewModel.content.isEmpty ? 0.25 : 1)
                    }

                    // Character count
                    HStack {
                        Spacer()
                        Text("\(viewModel.contentCharacterCount)/\(viewModel.maxContentLength)")
                            .font(.caption)
                            .foregroundColor(viewModel.contentCharacterCount > viewModel.maxContentLength ? .red : .secondary)
                    }
                } header: {
                    Text("messaging.content".localized)
                }

                // Attachments Section
                Section {
                    AttachmentPickerView(
                        attachments: $viewModel.pendingAttachments,
                        maxAttachments: viewModel.maxAttachments,
                        onAddImage: { image in
                            viewModel.addAttachment(image: image)
                        },
                        onRemoveAttachment: { id in
                            viewModel.removeAttachment(id: id)
                        }
                    )
                }

                // Device Info Section
                Section {
                    Toggle(isOn: $viewModel.includeDeviceInfo) {
                        HStack {
                            Image(systemName: "iphone")
                                .foregroundColor(.secondary)
                            Text("messaging.includeDeviceInfo".localized)
                        }
                    }

                    if viewModel.includeDeviceInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.deviceInfo.model)
                                .font(.caption)
                            Text(viewModel.deviceInfo.systemVersion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("App \(viewModel.deviceInfo.appVersion)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text("Device information helps us diagnose issues more effectively.")
                        .font(.caption)
                }
            }
            .navigationTitle("messaging.newMessage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("messaging.send".localized) {
                        Task {
                            if await viewModel.sendMessage() {
                                // Handle success for both authenticated and guest users
                                if let thread = viewModel.createdThread {
                                    onSuccess(thread)
                                } else if viewModel.createdGuestFeedback != nil {
                                    // Guest feedback was created successfully, dismiss the view
                                    dismiss()
                                }
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid || viewModel.isSending)
                }
            }
            .overlay {
                if viewModel.isSending {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)

                            Text("Sending...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(32)
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(16)
                    }
                }
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
