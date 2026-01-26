import SwiftUI

/// View for managing audiobook downloads
struct AudiobookDownloadsView: View {
    @StateObject private var downloadManager = AudiobookDownloadManager.shared
    @StateObject private var cacheManager = AudioCacheManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAllConfirmation = false
    @State private var selectedAudiobook: DownloadedAudiobook?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                storageSection

                if !downloadManager.downloadingAudiobooks.isEmpty {
                    activeDownloadsSection
                }

                if !downloadManager.downloadedAudiobooks.isEmpty {
                    downloadedAudiobooksSection
                }

                if downloadManager.downloadingAudiobooks.isEmpty && downloadManager.downloadedAudiobooks.isEmpty {
                    emptyStateSection
                }
            }
            .navigationTitle(L10n.Audiobook.downloads)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.Common.done) {
                        dismiss()
                    }
                }

                if !downloadManager.downloadedAudiobooks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteAllConfirmation = true
                            } label: {
                                Label(L10n.Audiobook.deleteAllDownloads, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .confirmationDialog(
                L10n.Audiobook.deleteAllConfirmation,
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Audiobook.deleteAll, role: .destructive) {
                    deleteAllDownloads()
                }
                Button(L10n.Common.cancel, role: .cancel) {}
            }
            .confirmationDialog(
                L10n.Audiobook.deleteDownloadConfirmation,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.Common.delete, role: .destructive) {
                    if let audiobook = selectedAudiobook {
                        downloadManager.deleteAudiobook(audiobookId: audiobook.audiobookId)
                    }
                    selectedAudiobook = nil
                }
                Button(L10n.Common.cancel, role: .cancel) {
                    selectedAudiobook = nil
                }
            }
        }
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            VStack(spacing: 16) {
                storageIndicator

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.Audiobook.downloaded)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(cacheManager.formattedDownloadsSize)
                            .font(.headline)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(L10n.Audiobook.cached)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(cacheManager.formattedCacheSize)
                            .font(.headline)
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text(L10n.Audiobook.storage)
        }
    }

    private var storageIndicator: some View {
        let storageInfo = cacheManager.getStorageInfo()

        return VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))

                    // Downloaded portion
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * min(storageInfo.usedPercentage, 1.0))
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(storageInfo.formattedDownloadedSize) / \(storageInfo.formattedMaxStorage)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if storageInfo.hasStorageWarning {
                    Label(L10n.Audiobook.storageWarning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }

    // MARK: - Active Downloads Section

    private var activeDownloadsSection: some View {
        Section {
            ForEach(Array(downloadManager.downloadingAudiobooks.values), id: \.audiobookId) { state in
                ActiveDownloadRow(state: state)
            }
        } header: {
            Text(L10n.Audiobook.downloading)
        }
    }

    // MARK: - Downloaded Audiobooks Section

    private var downloadedAudiobooksSection: some View {
        Section {
            ForEach(downloadManager.downloadedAudiobooks) { audiobook in
                DownloadedAudiobookRow(audiobook: audiobook)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            selectedAudiobook = audiobook
                            showDeleteConfirmation = true
                        } label: {
                            Label(L10n.Common.delete, systemImage: "trash")
                        }
                    }
            }
        } header: {
            Text(L10n.Audiobook.downloadedAudiobooks)
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text(L10n.Audiobook.noDownloads)
                    .font(.headline)
                    .foregroundColor(.secondary)

                Text(L10n.Audiobook.noDownloadsDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Actions

    private func deleteAllDownloads() {
        for audiobook in downloadManager.downloadedAudiobooks {
            downloadManager.deleteAudiobook(audiobookId: audiobook.audiobookId)
        }
        cacheManager.clearAllDownloads()
    }
}

// MARK: - Active Download Row

private struct ActiveDownloadRow: View {
    let state: AudiobookDownloadState
    @StateObject private var downloadManager = AudiobookDownloadManager.shared

    private var audiobook: DownloadedAudiobook? {
        downloadManager.downloadedAudiobooks.first { $0.audiobookId == state.audiobookId }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Progress circle
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: state.overallProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(state.overallProgress * 100))%")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(audiobook?.title ?? L10n.Audiobook.downloading)
                    .font(.headline)
                    .lineLimit(1)

                if let chapterCount = audiobook?.totalChapters {
                    let downloaded = state.chapterProgress.values.filter { $0 >= 1.0 }.count
                    Text("\(downloaded) / \(chapterCount) \(L10n.Audiobook.chapters)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let speed = state.formattedSpeed {
                    Text(speed)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Control buttons
            HStack(spacing: 12) {
                if state.status == .downloading {
                    Button {
                        downloadManager.pauseDownload(audiobookId: state.audiobookId)
                    } label: {
                        Image(systemName: "pause.fill")
                            .foregroundColor(.blue)
                    }
                } else if state.status == .paused {
                    Button {
                        downloadManager.resumeDownload(audiobookId: state.audiobookId)
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundColor(.blue)
                    }
                }

                Button {
                    downloadManager.cancelDownload(audiobookId: state.audiobookId)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Downloaded Audiobook Row

private struct DownloadedAudiobookRow: View {
    let audiobook: DownloadedAudiobook
    @StateObject private var cacheManager = AudioCacheManager.shared

    var body: some View {
        HStack(spacing: 12) {
            // Cover image
            AsyncImage(url: URL(string: audiobook.coverUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay {
                            Image(systemName: "headphones")
                                .foregroundColor(.secondary)
                        }
                @unknown default:
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                Text(audiobook.title)
                    .font(.headline)
                    .lineLimit(1)

                Text(audiobook.author)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(audiobook.downloadedChapters)/\(audiobook.totalChapters)", systemImage: "list.bullet")

                    Text("•")

                    Text(audiobook.formattedSize)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            if audiobook.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("\(Int(audiobook.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Localization Keys

private enum L10n {
    enum Common {
        static let done = NSLocalizedString("common.done", value: "Done", comment: "Done button")
        static let cancel = NSLocalizedString("common.cancel", value: "Cancel", comment: "Cancel button")
        static let delete = NSLocalizedString("common.delete", value: "Delete", comment: "Delete button")
    }

    enum Audiobook {
        static let downloads = NSLocalizedString("audiobook.downloads", value: "Downloads", comment: "Downloads title")
        static let storage = NSLocalizedString("audiobook.storage", value: "Storage", comment: "Storage section header")
        static let downloaded = NSLocalizedString("audiobook.downloaded", value: "Downloaded", comment: "Downloaded label")
        static let cached = NSLocalizedString("audiobook.cached", value: "Cached", comment: "Cached label")
        static let downloading = NSLocalizedString("audiobook.downloading", value: "Downloading", comment: "Downloading status")
        static let chapters = NSLocalizedString("audiobook.chapters", value: "chapters", comment: "Chapters label")
        static let downloadedAudiobooks = NSLocalizedString("audiobook.downloadedAudiobooks", value: "Downloaded Audiobooks", comment: "Downloaded audiobooks section")
        static let noDownloads = NSLocalizedString("audiobook.noDownloads", value: "No Downloads", comment: "No downloads title")
        static let noDownloadsDescription = NSLocalizedString("audiobook.noDownloadsDescription", value: "Download audiobooks for offline listening", comment: "No downloads description")
        static let deleteAllDownloads = NSLocalizedString("audiobook.deleteAllDownloads", value: "Delete All Downloads", comment: "Delete all button")
        static let deleteAllConfirmation = NSLocalizedString("audiobook.deleteAllConfirmation", value: "Delete all downloaded audiobooks?", comment: "Delete all confirmation")
        static let deleteAll = NSLocalizedString("audiobook.deleteAll", value: "Delete All", comment: "Delete all action")
        static let deleteDownloadConfirmation = NSLocalizedString("audiobook.deleteDownloadConfirmation", value: "Delete this download?", comment: "Delete download confirmation")
        static let storageWarning = NSLocalizedString("audiobook.storageWarning", value: "Low Storage", comment: "Storage warning label")
    }
}
