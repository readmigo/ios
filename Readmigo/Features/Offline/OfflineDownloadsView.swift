import SwiftUI

struct OfflineDownloadsView: View {
    @StateObject private var offlineManager = OfflineManager.shared
    @State private var showDeleteAlert = false
    @State private var bookToDelete: DownloadedBook?

    var body: some View {
        List {
            // Storage Info Section
            if let storageInfo = offlineManager.storageInfo {
                Section {
                    StorageInfoView(storageInfo: storageInfo)
                }
            }

            // Network Status
            Section {
                HStack {
                    Image(systemName: offlineManager.networkStatus.icon)
                        .foregroundColor(offlineManager.networkStatus.canDownload ? .green : .red)
                    Text("Network")
                    Spacer()
                    Text(offlineManager.networkStatus.displayName)
                        .foregroundColor(.secondary)
                }
            }

            // Active Downloads
            if !offlineManager.downloadQueue.isEmpty {
                Section("Active Downloads") {
                    ForEach(offlineManager.downloadQueue.filter { $0.status == .downloading || $0.status == .queued }.prefix(5)) { task in
                        DownloadTaskRow(task: task)
                    }

                    if offlineManager.downloadQueue.count > 5 {
                        Text("\(offlineManager.downloadQueue.count - 5) more in queue...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Downloaded Books
            Section("Downloaded Books") {
                if offlineManager.downloadedBooks.isEmpty {
                    EmptyDownloadsView()
                } else {
                    ForEach(offlineManager.downloadedBooks) { book in
                        DownloadedBookRow(book: book)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    bookToDelete = book
                                    showDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                if book.status == .downloading || book.status == .queued {
                                    Button {
                                        offlineManager.pauseDownload(bookId: book.bookId)
                                    } label: {
                                        Label("Pause", systemImage: "pause")
                                    }
                                    .tint(.orange)
                                } else if book.status == .paused {
                                    Button {
                                        Task {
                                            await offlineManager.resumeDownload(bookId: book.bookId)
                                        }
                                    } label: {
                                        Label("Resume", systemImage: "play")
                                    }
                                    .tint(.blue)
                                }
                            }
                    }
                }
            }

            // Actions
            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                    bookToDelete = nil
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete All Downloads")
                    }
                }
                .disabled(offlineManager.downloadedBooks.isEmpty)
            }
        }
        .navigationTitle("Downloads")
        .elegantRefreshable {
            await offlineManager.refreshStorageInfo()
        }
        .alert("Delete Download", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if let book = bookToDelete {
                        await offlineManager.deleteBook(bookId: book.bookId)
                    } else {
                        await offlineManager.deleteAllOfflineContent()
                    }
                }
            }
        } message: {
            if let book = bookToDelete {
                Text("Are you sure you want to delete \"\(book.title)\"? This will remove the offline content.")
            } else {
                Text("Are you sure you want to delete all downloaded content? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Storage Info View

struct StorageInfoView: View {
    let storageInfo: StorageInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Offline Content")
                        .font(.headline)
                    Text(storageInfo.formattedOfflineSize)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                Spacer()
                CircularProgressView(progress: storageInfo.offlinePercentage)
                    .frame(width: 50, height: 50)
            }

            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(storageInfo.formattedAvailableSpace)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading) {
                    Text("Used")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(storageInfo.formattedUsedSpace)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                VStack(alignment: .leading) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(storageInfo.formattedTotalSpace)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 6)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.bold)
        }
    }
}

// MARK: - Download Task Row

struct DownloadTaskRow: View {
    let task: DownloadTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.status.icon)
                .foregroundColor(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.type == .cover ? "Cover Image" : "Chapter")
                    .font(.subheadline)

                if task.status == .downloading {
                    ProgressView(value: task.progress)
                        .progressViewStyle(.linear)
                }
            }

            Spacer()

            Text(task.status.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusColor: Color {
        switch task.status {
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        case .queued: return .gray
        case .notDownloaded: return .gray
        }
    }
}

// MARK: - Downloaded Book Row

struct DownloadedBookRow: View {
    let book: DownloadedBook
    @StateObject private var offlineManager = OfflineManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let localPath = book.coverLocalPath {
                AsyncImage(url: URL(fileURLWithPath: localPath)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    bookPlaceholder
                }
                .frame(width: 50, height: 70)
                .cornerRadius(6)
            } else if let coverUrl = book.coverUrl, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    bookPlaceholder
                }
                .frame(width: 50, height: 70)
                .cornerRadius(6)
            } else {
                bookPlaceholder
                    .frame(width: 50, height: 70)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.localizedTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(book.localizedAuthor)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Status
                    Label(book.status.displayName, systemImage: book.status.icon)
                        .font(.caption2)
                        .foregroundColor(statusColor)

                    // Size
                    Text(book.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Progress bar for incomplete downloads
                if book.status == .downloading || book.status == .queued {
                    ProgressView(value: book.progress)
                        .progressViewStyle(.linear)
                }
            }

            Spacer()

            // Download indicator
            if book.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("\(book.downloadedChapters)/\(book.totalChapters)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var bookPlaceholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: "book.closed")
                    .foregroundColor(.gray)
            )
    }

    private var statusColor: Color {
        switch book.status {
        case .completed: return .green
        case .downloading: return .blue
        case .paused: return .orange
        case .failed: return .red
        case .queued: return .gray
        case .notDownloaded: return .gray
        }
    }
}

// MARK: - Empty Downloads View

struct EmptyDownloadsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Downloads")
                .font(.headline)

            Text("Books you download will appear here for offline reading.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
