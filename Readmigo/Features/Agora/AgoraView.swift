import SwiftUI
import Combine

// MARK: - AgoraView

struct AgoraView: View {
    @StateObject private var manager = AgoraManager.shared
    @State private var scrollProxy: ScrollViewProxy?
    private let tabDoubleTapPublisher = NotificationCenter.default.publisher(for: .agoraTabDoubleTapped)

    var body: some View {
        NavigationStack {
            Group {
                if manager.posts.isEmpty && manager.isLoading {
                    loadingView
                } else if manager.posts.isEmpty && manager.errorMessage != nil {
                    errorView
                } else if manager.posts.isEmpty {
                    emptyView
                } else {
                    contentView
                }
            }
            .navigationTitle("nav.agora".localized)
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            if manager.posts.isEmpty {
                await manager.fetchPosts(refresh: true)
            }
        }
        .onReceive(tabDoubleTapPublisher) { _ in
            // Scroll to top when tab is double-tapped
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy?.scrollTo("agoraScrollTop", anchor: .top)
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Scroll anchor for scroll-to-top
                    Color.clear
                        .frame(height: 0)
                        .id("agoraScrollTop")

                    // Offline banner when viewing cached data
                    if manager.dataSource == .cache {
                        OfflineBannerView(lastSyncTime: manager.lastSyncTime) {
                            Task {
                                await manager.refreshPosts()
                            }
                        }
                        .padding(.horizontal)
                    }

                    ForEach(manager.posts) { post in
                        AgoraPostCard(post: post, manager: manager)
                            .padding(.horizontal)
                            .onAppear {
                                loadMoreIfNeeded(currentPost: post)
                            }
                    }

                    if manager.isLoading && !manager.posts.isEmpty {
                        ProgressView()
                            .padding()
                    }

                    if !manager.hasMorePosts && !manager.posts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.title2)
                                .foregroundColor(.secondary)
                            Text("agora.endOfFeed".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 32)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .elegantRefreshable {
                await manager.refreshPosts()
            }
            .onAppear {
                scrollProxy = proxy
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("common.loading".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("error.loadFailed".localized)
                .font(.headline)

            if let error = manager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task {
                    await manager.fetchPosts(refresh: true)
                }
            } label: {
                Text("common.retry".localized)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("agora.welcome".localized)
                .font(.title2)
                .fontWeight(.semibold)

            Text("agora.comingSoon".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Load More

    private func loadMoreIfNeeded(currentPost: AgoraPost) {
        let thresholdIndex = manager.posts.index(manager.posts.endIndex, offsetBy: -3)
        if let currentIndex = manager.posts.firstIndex(where: { $0.id == currentPost.id }),
           currentIndex >= thresholdIndex {
            Task {
                await manager.loadMorePosts()
            }
        }
    }
}

// MARK: - Blocked List View

struct BlockedListView: View {
    @ObservedObject var manager: AgoraManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if manager.blockedAuthors.isEmpty && manager.hiddenPosts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.title)
                            .foregroundColor(.green)
                        Text("agora.noBlockedContent".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 48)
                    .listRowBackground(Color.clear)
                } else {
                    if !manager.blockedAuthors.isEmpty {
                        Section("agora.blockedAuthors".localized) {
                            ForEach(Array(manager.blockedAuthors), id: \.self) { authorId in
                                HStack {
                                    Text(authorId)
                                        .font(.subheadline)

                                    Spacer()

                                    Button("agora.unblock".localized) {
                                        Task {
                                            await manager.unblockAuthor(authorId)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }

                    if !manager.hiddenPosts.isEmpty {
                        Section("agora.hiddenPosts".localized) {
                            Text("agora.postsCount".localized(with: manager.hiddenPosts.count))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("agora.blocked".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}
