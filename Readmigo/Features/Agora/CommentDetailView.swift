import SwiftUI

struct CommentDetailView: View {
    let post: AgoraPost
    @ObservedObject var manager: AgoraManager
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [Comment] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var currentPage = 1
    @State private var totalComments = 0

    @State private var commentText = ""
    @State private var replyToComment: Comment?
    @State private var showLoginPrompt = false

    private let pageSize = 20
    private let maxCommentLength = 2000

    private var isGuest: Bool {
        !authManager.isAuthenticated
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    postSummaryView
                        .padding(16)

                    Divider()

                    commentHeaderView
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)

                    if isLoading && comments.isEmpty {
                        loadingView
                    } else if comments.isEmpty {
                        emptyStateView
                    } else {
                        commentsListView
                    }
                }
            }

            Divider()

            commentInputView
                .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("agora.comments".localized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadComments()
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginPromptView(feature: "comment") {
                showLoginPrompt = false
            }
            .environmentObject(authManager)
        }
    }

    // MARK: - Post Summary

    private var postSummaryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if post.isAuthorPost, let author = post.author {
                    AuthorAvatarView(author: author, size: 40)
                } else {
                    SmallAvatarView(
                        userName: post.displayName,
                        avatarUrl: post.displayAvatarUrl,
                        size: 40
                    )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(post.relativeTimeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            if post.isAuthorPost, let quote = post.quote {
                Text("\"\(quote.text)\"")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            } else if let content = post.content {
                Text(content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Comment Header

    private var commentHeaderView: some View {
        HStack {
            Text("agora.allComments".localized(with: totalComments > 0 ? totalComments : post.commentCount))
                .font(.headline)

            Spacer()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("agora.loadingComments".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("agora.noComments".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("agora.beFirstToComment".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Comments List

    private var commentsListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(comments) { comment in
                VStack(spacing: 0) {
                    CommentCell(
                        comment: comment,
                        isOwner: authManager.currentUser?.id == comment.userId,
                        onLike: {
                            Task {
                                await handleLikeComment(comment)
                            }
                        },
                        onReply: {
                            handleReply(to: comment)
                        },
                        onDelete: {
                            Task {
                                await handleDeleteComment(comment)
                            }
                        }
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.leading, 56)
                }
                .background(Color(.systemBackground))
                .onAppear {
                    if comment.id == comments.last?.id && hasMore && !isLoadingMore {
                        Task {
                            await loadMoreComments()
                        }
                    }
                }
            }

            if isLoadingMore {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("agora.loadingComments".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            } else if !hasMore && !comments.isEmpty {
                Text("agora.noMoreComments".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    // MARK: - Comment Input

    private var commentInputView: some View {
        VStack(spacing: 8) {
            if let replyTo = replyToComment {
                HStack {
                    Text("agora.replyingTo".localized(with: replyTo.userName))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button {
                        replyToComment = nil
                        commentText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            HStack(spacing: 12) {
                TextField(replyToComment != nil ? "agora.writeReply".localized : "agora.writeComment".localized, text: $commentText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .onChange(of: commentText) { _, newValue in
                        if newValue.count > maxCommentLength {
                            commentText = String(newValue.prefix(maxCommentLength))
                        }
                    }

                Button {
                    if isGuest {
                        showLoginPrompt = true
                    } else {
                        Task {
                            await sendComment()
                        }
                    }
                } label: {
                    Text("common.send".localized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isCommentValid ? .accentColor : .secondary)
                }
                .disabled(!isCommentValid)
            }

            if commentText.count > maxCommentLength - 200 {
                HStack {
                    Spacer()
                    Text("\(commentText.count)/\(maxCommentLength)")
                        .font(.caption2)
                        .foregroundColor(commentText.count >= maxCommentLength ? .red : .secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }

    private var isCommentValid: Bool {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && commentText.count <= maxCommentLength
    }

    // MARK: - Actions

    private func loadComments() async {
        guard !isLoading else { return }
        isLoading = true
        currentPage = 1

        let result = await manager.fetchCommentsPaginated(for: post.id, page: currentPage, limit: pageSize)
        comments = result.comments
        hasMore = result.hasMore
        totalComments = result.total
        currentPage += 1

        isLoading = false
    }

    private func loadMoreComments() async {
        guard !isLoadingMore && hasMore else { return }
        isLoadingMore = true

        let result = await manager.fetchCommentsPaginated(for: post.id, page: currentPage, limit: pageSize)
        comments.append(contentsOf: result.comments)
        hasMore = result.hasMore
        totalComments = result.total
        currentPage += 1

        isLoadingMore = false
    }

    private func sendComment() async {
        let content = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        let replyToId = replyToComment?.id

        let newComment = Comment(
            id: UUID().uuidString,
            postId: post.id,
            userId: authManager.currentUser?.id ?? "current-user",
            userName: authManager.currentUser?.displayName ?? "我",
            userAvatar: authManager.currentUser?.avatarUrl,
            content: content,
            createdAt: Date(),
            likeCount: 0,
            isLiked: false,
            replyTo: replyToId,
            replyToUserName: replyToComment?.userName
        )

        comments.insert(newComment, at: 0)
        totalComments += 1
        commentText = ""
        replyToComment = nil

        await manager.addComment(to: post.id, content: content, replyTo: replyToId)
    }

    private func handleLikeComment(_ comment: Comment) async {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        if isGuest {
            showLoginPrompt = true
            return
        }

        comments[index].isLiked.toggle()
        if comments[index].isLiked {
            comments[index].likeCount += 1
        } else {
            comments[index].likeCount -= 1
        }

        await manager.likeComment(comment.id, in: post.id)
    }

    private func handleReply(to comment: Comment) {
        if isGuest {
            showLoginPrompt = true
            return
        }
        replyToComment = comment
    }

    private func handleDeleteComment(_ comment: Comment) async {
        guard let index = comments.firstIndex(where: { $0.id == comment.id }) else { return }

        let deletedComment = comments[index]
        comments.remove(at: index)
        totalComments = max(0, totalComments - 1)

        let success = await manager.deleteComment(comment.id, in: post.id)
        if !success {
            comments.insert(deletedComment, at: index)
            totalComments += 1
        }
    }
}
