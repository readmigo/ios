import SwiftUI
import UniformTypeIdentifiers

/// Import entry button and sheet
struct ImportButton: View {
    @StateObject private var viewModel = ImportViewModel()
    @State private var showImportSheet = false

    var body: some View {
        Button {
            showImportSheet = true
        } label: {
            Image(systemName: "plus")
                .font(.title3)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheetView(viewModel: viewModel) {
                showImportSheet = false
            }
        }
    }
}

/// Import sheet with method selection
struct ImportSheetView: View {
    @ObservedObject var viewModel: ImportViewModel
    let onDismiss: () -> Void

    @State private var showingFilePicker = false

    /// Supported file types for import
    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [.epub, .plainText, .pdf]
        // Add MOBI type
        if let mobiType = UTType(filenameExtension: "mobi") {
            types.append(mobiType)
        }
        // Add AZW3 type
        if let azw3Type = UTType(filenameExtension: "azw3") {
            types.append(azw3Type)
        }
        // Add AZW type
        if let azwType = UTType(filenameExtension: "azw") {
            types.append(azwType)
        }
        return types
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)

                    Text("import.title".localized)
                        .font(.title2.bold())

                    Text("import.subtitle".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // Quota display
                if let quota = viewModel.quota {
                    QuotaDisplayView(quota: quota)
                        .padding(.horizontal)
                }

                // Import methods
                VStack(spacing: 12) {
                    ImportMethodRow(
                        icon: "folder",
                        title: "import.method.files".localized,
                        subtitle: "import.method.files.desc".localized
                    ) {
                        showingFilePicker = true
                    }

                    ImportMethodRow(
                        icon: "icloud",
                        title: "import.method.icloud".localized,
                        subtitle: "import.method.icloud.desc".localized,
                        isDisabled: true,
                        disabledReason: "Coming Soon"
                    ) {
                        // iCloud import
                    }

                    ImportMethodRow(
                        icon: "wifi",
                        title: "import.method.wifi".localized,
                        subtitle: "import.method.wifi.desc".localized,
                        isDisabled: true,
                        disabledReason: "Coming Soon"
                    ) {
                        // WiFi transfer
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Supported formats
                VStack(spacing: 8) {
                    Text("import.supportedFormats".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        FormatBadge(format: "EPUB", color: .blue)
                        FormatBadge(format: "TXT", color: .gray)
                        FormatBadge(format: "PDF", color: .red)
                        FormatBadge(format: "MOBI", color: .orange)
                        FormatBadge(format: "AZW3", color: .purple)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("import.action.cancel".localized) {
                        onDismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: ImportSheetView.supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task {
                            await viewModel.handleFileSelected(url: url)
                        }
                    }
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
            .overlay {
                if viewModel.state.isActive || viewModel.state == .completed(ImportedBookSummary(id: "", title: "", author: nil, coverUrl: nil, chapterCount: 0, wordCount: nil)) {
                    ImportProgressView(viewModel: viewModel)
                }
            }
            .alert("import.upgradeRequired.title".localized, isPresented: $viewModel.showUpgradePrompt) {
                Button("import.action.upgrade".localized) {
                    // Navigate to subscription
                }
                Button("import.action.cancel".localized, role: .cancel) {}
            } message: {
                Text("import.upgradeRequired.message".localized)
            }
            .alert("import.quotaExceeded.title".localized, isPresented: $viewModel.showQuotaExceeded) {
                Button("OK") {}
            } message: {
                Text("import.quotaExceeded.message".localized)
            }
            .task {
                // Fetch quota on appear
                _ = try? await ImportService.shared.fetchQuota()
                viewModel.quota = ImportService.shared.quota
            }
        }
    }
}

// MARK: - Supporting Views

struct ImportMethodRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isDisabled: Bool = false
    var disabledReason: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDisabled ? .gray : .accentColor)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isDisabled ? .secondary : .primary)

                        if let reason = disabledReason {
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .disabled(isDisabled)
    }
}

struct QuotaDisplayView: View {
    let quota: ImportQuota

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("import.quota.title".localized)
                    .font(.subheadline.bold())
                Spacer()
                Text("\(quota.used.bookCount)/\(quota.limit.bookCount) " + "import.quota.books".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(quotaColor)
                        .frame(width: geometry.size.width * quota.usagePercentage)
                }
            }
            .frame(height: 8)

            HStack {
                Text(quota.used.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(quota.limit.formattedSize)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var quotaColor: Color {
        if quota.usagePercentage > 0.9 {
            return .red
        } else if quota.usagePercentage > 0.7 {
            return .orange
        }
        return .green
    }
}

struct FormatBadge: View {
    let format: String
    let color: Color

    var body: some View {
        Text(format)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(8)
    }
}
