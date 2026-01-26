import SwiftUI

// MARK: - AgoraPostCard

struct AgoraPostCard: View {
    let post: AgoraPost
    @ObservedObject var manager: AgoraManager
    @EnvironmentObject private var authManager: AuthManager

    @State private var showAllComments = false
    @State private var showCommentInput = false
    @State private var commentText = ""
    @State private var showMoreActions = false
    @State private var isLikeAnimating = false
    @State private var showLoginPrompt = false
    @State private var showShareSheet = false

    private var isGuest: Bool {
        !authManager.isAuthenticated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Avatar + Author/User + Time + More
            headerView

            Divider()
                .padding(.vertical, 12)

            // Content: Quote text (author) or user content + media
            contentView

            // Source: Book info (only for author posts)
            if post.isAuthorPost && !post.sourceString.isEmpty {
                sourceView
                    .padding(.top, 12)
            }

            Divider()
                .padding(.vertical, 12)

            // Actions: Like, Comment, Share
            actionsView

            // Comments section
            if let comments = post.comments, !comments.isEmpty {
                commentsSection(comments: comments)
            }

            // Comment input
            if showCommentInput {
                commentInputView
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onTapGesture(count: 2) {
            doubleTapLike()
        }
        .confirmationDialog("agora.moreActions".localized, isPresented: $showMoreActions, titleVisibility: .visible) {
            Button("agora.notInterested".localized) {
                Task {
                    await manager.hidePost(post.id)
                }
            }
            if post.isAuthorPost, let author = post.author {
                Button("agora.blockAuthor".localized) {
                    Task {
                        await manager.blockAuthor(author.id)
                    }
                }
            }
            Button("agora.report".localized, role: .destructive) {
                Task {
                    await manager.reportPost(post.id, reason: "inappropriate")
                }
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .sheet(isPresented: $showLoginPrompt) {
            LoginPromptView(feature: "like") {
                showLoginPrompt = false
            }
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheetView(post: post, manager: manager)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar and info section
            HStack(spacing: 12) {
                // Avatar
                avatarView

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        // Name
                        Text(post.displayName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        // Author label (only for author posts)
                        if post.isAuthorPost {
                            Text("agora.authorLabel".localized)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(post.relativeTimeString)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if post.isAuthorPost, let location = post.locationString {
                            Text("·")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if post.isAuthorPost, let author = post.author {
                    // Navigate to author profile (handled separately)
                }
            }

            Spacer()

            Button {
                showMoreActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if post.isAuthorPost, let author = post.author {
            NavigationLink {
                AuthorProfileView(authorId: author.id)
            } label: {
                AuthorAvatarView(author: author, size: 44)
            }
            .buttonStyle(.plain)
        } else {
            SmallAvatarView(
                userName: post.displayName,
                avatarUrl: post.displayAvatarUrl,
                size: 44
            )
        }
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        if post.isAuthorPost, let quote = post.quote {
            // Author post: Show quote
            Text(quote.text)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = quote.text
                    } label: {
                        Label("common.copyText".localized, systemImage: "doc.on.doc")
                    }
                }
        } else {
            // User post: Show content and media
            VStack(alignment: .leading, spacing: 12) {
                if let content = post.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = content
                            } label: {
                                Label("common.copyText".localized, systemImage: "doc.on.doc")
                            }
                        }
                }

                if let media = post.media, !media.isEmpty {
                    PostMediaGridView(media: media)
                }
            }
        }
    }

    // MARK: - Source View

    private var sourceView: some View {
        HStack(spacing: 6) {
            Image(systemName: "book.closed")
                .font(.caption)
                .foregroundColor(.secondary)

            Text(post.sourceString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions View

    /// 是否是自己发布的帖子（USER类型）
    private var isOwnPost: Bool {
        guard let currentUserId = authManager.currentUser?.id else { return false }
        return post.isUserPost && post.user?.id == currentUserId
    }

    private var actionsView: some View {
        HStack(spacing: 32) {
            // Like button
            Button {
                if isGuest {
                    showLoginPrompt = true
                } else if isOwnPost {
                    // 自己的帖子不能点赞，不做任何操作
                    return
                } else {
                    Task {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLikeAnimating = true
                        }
                        await manager.toggleLike(post.id)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isLikeAnimating = false
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(.body)
                        .foregroundColor(post.isLiked ? .red : .secondary)
                        .scaleEffect(isLikeAnimating ? 1.3 : 1.0)

                    Text("\(post.likeCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .disabled(isOwnPost)
            .opacity(isOwnPost ? 0.5 : 1.0)

            // Comment button
            Button {
                if isGuest {
                    showLoginPrompt = true
                } else {
                    withAnimation {
                        showCommentInput.toggle()
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.hasUserComment ? "bubble.right.fill" : "bubble.right")
                        .font(.body)
                        .foregroundColor(post.hasUserComment ? .blue : .secondary)

                    Text("\(post.commentCount)")
                        .font(.subheadline)
                        .foregroundColor(post.hasUserComment ? .blue : .secondary)
                }
            }
            .buttonStyle(.plain)

            // Share button
            Button {
                showShareSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("\(post.shareCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Comments Section

    @ViewBuilder
    private func commentsSection(comments: [Comment]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 8) {
                let displayComments = showAllComments ? comments : Array(comments.prefix(3))
                let currentUserId = authManager.currentUser?.id

                ForEach(displayComments) { comment in
                    CommentCell(
                        comment: comment,
                        isOwner: currentUserId != nil && comment.userId == currentUserId,
                        onLike: {
                            Task {
                                await manager.likeComment(comment.id, in: post.id)
                            }
                        },
                        onReply: {
                            commentText = "@\(comment.userName) "
                            showCommentInput = true
                        },
                        onDelete: {
                            Task {
                                await manager.deleteComment(comment.id, in: post.id)
                            }
                        }
                    )
                }

                if post.hasMoreComments && !showAllComments {
                    NavigationLink {
                        CommentDetailView(post: post, manager: manager)
                    } label: {
                        Text("agora.viewAllComments".localized(with: post.commentCount))
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }

    // MARK: - Comment Input View

    private let maxCommentLength = 2000

    private var commentInputView: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.top, 12)

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 12) {
                    TextField("agora.writeComment".localized, text: $commentText)
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
                        guard !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        Task {
                            await manager.addComment(to: post.id, content: commentText)
                            commentText = ""
                            showCommentInput = false
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
                    Text("\(commentText.count)/\(maxCommentLength)")
                        .font(.caption2)
                        .foregroundColor(commentText.count >= maxCommentLength ? .red : .secondary)
                }
            }
            .padding(.top, 12)
        }
    }

    private var isCommentValid: Bool {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && commentText.count <= maxCommentLength
    }

    // MARK: - Double Tap Like

    private func doubleTapLike() {
        if isGuest {
            showLoginPrompt = true
            return
        }
        if !post.isLiked {
            Task {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLikeAnimating = true
                }
                await manager.likePost(post.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isLikeAnimating = false
                }
            }
        }
    }
}

// MARK: - CommentCell

struct CommentCell: View {
    let comment: Comment
    let isOwner: Bool
    var onLike: (() -> Void)?
    var onReply: (() -> Void)?
    var onDelete: (() -> Void)?

    @State private var showDeleteConfirmation = false
    @State private var showCannotLikeOwnComment = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            SmallAvatarView(
                userName: comment.userName,
                avatarUrl: comment.userAvatar,
                size: 28
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(comment.userName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    if let replyTo = comment.replyToUserName {
                        Text("agora.replyTo".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(replyTo)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                }

                Text(comment.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 16) {
                    Text(comment.relativeTimeString)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button {
                        onReply?()
                    } label: {
                        Text("agora.reply".localized)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if isOwner {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("common.delete".localized)
                                .font(.caption2)
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }

                    Spacer()

                    Button {
                        if isOwner {
                            // 自己的评论不能点赞，显示提示
                            showCannotLikeOwnComment = true
                        } else {
                            onLike?()
                        }
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: comment.isLiked ? "heart.fill" : "heart")
                                .font(.caption2)
                                .foregroundColor(comment.isLiked ? .red : .secondary)

                            if comment.likeCount > 0 {
                                Text("\(comment.likeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .opacity(isOwner ? 0.5 : 1.0)
                }
            }
        }
        .confirmationDialog("agora.deleteCommentConfirm".localized, isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("common.delete".localized, role: .destructive) {
                onDelete?()
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .alert("agora.cannotLikeOwnComment".localized, isPresented: $showCannotLikeOwnComment) {
            Button("common.ok".localized, role: .cancel) {}
        }
    }
}

// MARK: - Share Card Style
// Matches backend PostcardTemplate definitions in postcards.service.ts

enum ShareCardStyle: String, CaseIterable, Identifiable {
    case classic = "classic"
    case vintage = "vintage"
    case modern = "modern"
    case nature = "nature"
    case elegant = "elegant"
    case minimal = "minimal"
    case ocean = "ocean"
    case sunset = "sunset"
    case literary = "literary"
    case polaroid = "polaroid"
    case gradient = "gradient"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: return "share.style.classic".localized
        case .vintage: return "share.style.vintage".localized
        case .modern: return "share.style.modern".localized
        case .nature: return "share.style.nature".localized
        case .elegant: return "share.style.elegant".localized
        case .minimal: return "share.style.minimal".localized
        case .ocean: return "share.style.ocean".localized
        case .sunset: return "share.style.sunset".localized
        case .literary: return "share.style.literary".localized
        case .polaroid: return "share.style.polaroid".localized
        case .gradient: return "share.style.gradient".localized
        }
    }

    var isPremium: Bool {
        switch self {
        case .classic, .vintage, .modern, .nature:
            return false
        case .elegant, .minimal, .ocean, .sunset, .literary, .polaroid, .gradient:
            return true
        }
    }

    var backgroundColor: Color {
        switch self {
        case .classic: return Color(hex: "#FFFFFF")
        case .vintage: return Color(hex: "#F5E6D3")
        case .modern: return Color(hex: "#1A1A2E")
        case .nature: return Color(hex: "#E8F5E9")
        case .elegant: return Color(hex: "#FFF8E1")
        case .minimal: return Color(hex: "#FAFAFA")
        case .ocean: return Color(hex: "#E3F2FD")
        case .sunset: return Color(hex: "#FFF3E0")
        case .literary: return Color(hex: "#FDF5E6")
        case .polaroid: return Color(hex: "#FFFFFF")
        case .gradient: return Color.clear // Uses gradient instead
        }
    }

    var textColor: Color {
        switch self {
        case .classic: return Color(hex: "#333333")
        case .vintage: return Color(hex: "#5D4037")
        case .modern: return Color(hex: "#FFFFFF")
        case .nature: return Color(hex: "#2E7D32")
        case .elegant: return Color(hex: "#6D4C41")
        case .minimal: return Color(hex: "#212121")
        case .ocean: return Color(hex: "#1565C0")
        case .sunset: return Color(hex: "#E65100")
        case .literary: return Color(hex: "#5D4E37")
        case .polaroid: return Color(hex: "#333333")
        case .gradient: return Color(hex: "#FFFFFF")
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .classic: return Color(hex: "#666666")
        case .vintage: return Color(hex: "#795548")
        case .modern: return Color(hex: "#CCCCCC")
        case .nature: return Color(hex: "#558B2F")
        case .elegant: return Color(hex: "#8D6E63")
        case .minimal: return Color(hex: "#616161")
        case .ocean: return Color(hex: "#1976D2")
        case .sunset: return Color(hex: "#F57C00")
        case .literary: return Color(hex: "#8B7355")
        case .polaroid: return Color(hex: "#666666")
        case .gradient: return Color(hex: "#FFFFFF").opacity(0.9)
        }
    }

    var fontFamily: String {
        switch self {
        case .classic: return "Merriweather"
        case .vintage: return "Playfair Display"
        case .modern: return "Inter"
        case .nature: return "Lora"
        case .elegant: return "Cormorant"
        case .minimal: return "Roboto"
        case .ocean: return "Quicksand"
        case .sunset: return "Poppins"
        case .literary: return "Georgia"
        case .polaroid: return "Georgia"
        case .gradient: return "SF Pro Display"
        }
    }

    var quoteFont: Font {
        // Use Georgia as fallback for custom fonts, with style matching the template
        switch self {
        case .classic:
            return .custom("Georgia", size: 17)
        case .vintage:
            return .custom("Georgia", size: 17).italic()
        case .modern:
            return .system(size: 17, weight: .medium, design: .default)
        case .nature:
            return .custom("Georgia", size: 17)
        case .elegant:
            return .custom("Georgia", size: 18).italic()
        case .minimal:
            return .system(size: 17, weight: .regular, design: .default)
        case .ocean:
            return .system(size: 17, weight: .medium, design: .rounded)
        case .sunset:
            return .system(size: 17, weight: .medium, design: .default)
        case .literary:
            return .custom("Georgia", size: 17).italic()
        case .polaroid:
            return .custom("Georgia", size: 15)
        case .gradient:
            return .system(size: 18, weight: .semibold, design: .default)
        }
    }

    var decorationIcon: String? {
        switch self {
        case .vintage: return "seal.fill"
        case .nature: return "leaf.fill"
        case .elegant: return "sparkles"
        case .ocean: return "drop.fill"
        case .sunset: return "sun.max.fill"
        case .literary: return "book.closed.fill"
        default: return nil
        }
    }

    var decorationColor: Color {
        switch self {
        case .vintage: return Color(hex: "#D2B48C").opacity(0.3)
        case .nature: return Color(hex: "#C8E6C9")
        case .elegant: return Color(hex: "#FFD54F").opacity(0.3)
        case .ocean: return Color(hex: "#90CAF9").opacity(0.5)
        case .sunset: return Color(hex: "#FFCC80").opacity(0.5)
        case .literary: return Color(hex: "#D4C4A8").opacity(0.4)
        default: return .clear
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .gradient:
            return [Color(hex: "#667eea"), Color(hex: "#764ba2")]
        default:
            return []
        }
    }

    var usesGradientBackground: Bool {
        self == .gradient
    }

    /// Convert ShareCardStyle to PostcardTemplate for use with ShareCardPreview
    func toTemplate() -> PostcardTemplate {
        PostcardTemplate(
            id: rawValue,
            name: displayName,
            previewUrl: nil,
            backgroundColor: backgroundColorHex,
            fontFamily: fontFamily,
            fontColor: textColorHex,
            isPremium: isPremium,
            isAvailable: true,
            category: nil,
            sortOrder: nil,
            secondaryColor: secondaryTextColorHex,
            decorationIcon: decorationIcon,
            gradientColors: usesGradientBackground ? gradientColorHexes : nil
        )
    }

    private var backgroundColorHex: String {
        switch self {
        case .classic: return "#FFFFFF"
        case .vintage: return "#F5E6D3"
        case .modern: return "#1A1A2E"
        case .nature: return "#E8F5E9"
        case .elegant: return "#FFF8E1"
        case .minimal: return "#FAFAFA"
        case .ocean: return "#E3F2FD"
        case .sunset: return "#FFF3E0"
        case .literary: return "#FDF5E6"
        case .polaroid: return "#FFFFFF"
        case .gradient: return "#667eea"
        }
    }

    private var textColorHex: String {
        switch self {
        case .classic: return "#333333"
        case .vintage: return "#5D4037"
        case .modern: return "#FFFFFF"
        case .nature: return "#2E7D32"
        case .elegant: return "#6D4C41"
        case .minimal: return "#212121"
        case .ocean: return "#1565C0"
        case .sunset: return "#E65100"
        case .literary: return "#5D4E37"
        case .polaroid: return "#333333"
        case .gradient: return "#FFFFFF"
        }
    }

    private var secondaryTextColorHex: String {
        switch self {
        case .classic: return "#666666"
        case .vintage: return "#795548"
        case .modern: return "#CCCCCC"
        case .nature: return "#558B2F"
        case .elegant: return "#8D6E63"
        case .minimal: return "#616161"
        case .ocean: return "#1976D2"
        case .sunset: return "#F57C00"
        case .literary: return "#8B7355"
        case .polaroid: return "#666666"
        case .gradient: return "#FFFFFF"
        }
    }

    private var gradientColorHexes: [String] {
        switch self {
        case .gradient: return ["#667eea", "#764ba2"]
        default: return []
        }
    }
}

// MARK: - Share Card Preview (Dynamic Template)

struct ShareCardPreview: View {
    let post: AgoraPost
    let template: PostcardTemplate

    var body: some View {
        ZStack {
            // Background
            backgroundView

            // Decoration (corner icons for some styles)
            if let icon = template.sfSymbolIcon {
                decorationView(icon: icon)
            }

            // Content
            VStack(spacing: 16) {
                Spacer()

                // Quote marks (for elegant and vintage styles)
                if shouldShowQuoteMarks {
                    Image(systemName: "quote.opening")
                        .font(.title2)
                        .foregroundColor(template.secondaryTxtColor.opacity(0.4))
                }

                // Quote text
                if post.isAuthorPost, let quote = post.quote {
                    Text(quote.text)
                        .font(template.quoteFont)
                        .foregroundColor(template.txtColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 24)
                } else if let content = post.content {
                    Text(content)
                        .font(template.quoteFont)
                        .foregroundColor(template.txtColor)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .lineLimit(6)
                        .padding(.horizontal, 24)
                }

                // Author
                Text("—— \(post.displayName)")
                    .font(.subheadline)
                    .foregroundColor(template.secondaryTxtColor)

                // Book title (for author posts)
                if post.isAuthorPost, let quote = post.quote, let bookTitle = quote.bookTitle {
                    Text("《\(bookTitle)》")
                        .font(.caption)
                        .foregroundColor(template.secondaryTxtColor)
                }

                Spacer()

                // Bottom branding
                bottomBranding
            }
            .padding(24)

            // Premium badge
            if template.isPremium && !(template.isAvailable ?? false) {
                premiumBadge
            }
        }
        .aspectRatio(3/4, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isLightBackground ? Color(.systemGray5) : Color.clear, lineWidth: 1)
        )
    }

    private var shouldShowQuoteMarks: Bool {
        let name = template.name.lowercased()
        return name.contains("elegant") || name.contains("vintage") || name.contains("literary")
    }

    private var isLightBackground: Bool {
        let name = template.name.lowercased()
        return name.contains("classic") || name.contains("minimal") || template.backgroundColor == "#FFFFFF" || template.backgroundColor == "#FAFAFA"
    }

    @ViewBuilder
    private var backgroundView: some View {
        if template.usesGradient {
            LinearGradient(
                colors: template.gradientColorValues,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            template.bgColor
        }
    }

    @ViewBuilder
    private func decorationView(icon: String) -> some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 50))
                    .foregroundColor(template.decorationColor)
                    .offset(x: 15, y: -15)
            }
            Spacer()
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 35))
                    .foregroundColor(template.decorationColor)
                    .rotationEffect(.degrees(180))
                    .offset(x: -10, y: 10)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var bottomBranding: some View {
        HStack {
            if template.name.lowercased() == "modern" {
                Rectangle()
                    .fill(template.txtColor)
                    .frame(width: 30, height: 2)
            }
            Spacer()
            Text("Readmigo")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(template.secondaryTxtColor.opacity(0.6))
        }
    }

    @ViewBuilder
    private var premiumBadge: some View {
        VStack {
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill")
                        .font(.caption2)
                    Text("Premium")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                Spacer()
            }
            .padding(12)
            Spacer()
        }
    }
}

// MARK: - Share Sheet View

struct ShareSheetView: View {
    let post: AgoraPost
    @ObservedObject var manager: AgoraManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var postcardsManager = PostcardsManager.shared

    @State private var selectedStyleIndex = 0
    @State private var renderedImage: UIImage?
    @State private var isLoadingTemplates = true

    /// Dynamic templates from API, with fallback to defaults
    private var templates: [PostcardTemplate] {
        postcardsManager.templates.isEmpty
            ? PostcardTemplate.defaultTemplates
            : postcardsManager.templates
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isLoadingTemplates && templates.isEmpty {
                    // Loading state
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("share.loadingTemplates".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Spacer()
                } else {
                    // Swipeable Card Preview
                    TabView(selection: $selectedStyleIndex) {
                        ForEach(Array(templates.enumerated()), id: \.element.id) { index, template in
                            ShareCardPreview(post: post, template: template)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 8)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 340)

                    // Style name and page indicator
                    VStack(spacing: 8) {
                        if !templates.isEmpty && selectedStyleIndex < templates.count {
                            Text(templates[selectedStyleIndex].displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .animation(.none, value: selectedStyleIndex)
                        }

                        // Custom page indicator
                        HStack(spacing: 6) {
                            ForEach(0..<templates.count, id: \.self) { index in
                                Circle()
                                    .fill(index == selectedStyleIndex ? Color.accentColor : Color(.systemGray4))
                                    .frame(width: 6, height: 6)
                                    .animation(.easeInOut(duration: 0.2), value: selectedStyleIndex)
                            }
                        }

                        Text("share.swipeToChange".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()
                        .padding(.horizontal)

                    // Share options
                    HStack(spacing: 32) {
                        ShareOptionButton(
                            icon: "photo",
                            title: "share.saveImage".localized,
                            color: .green
                        ) {
                            saveAsImage()
                        }

                        ShareOptionButton(
                            icon: "doc.on.doc",
                            title: "common.copyText".localized,
                            color: .blue
                        ) {
                            copyText()
                        }

                        ShareOptionButton(
                            icon: "square.and.arrow.up",
                            title: "share.more".localized,
                            color: .orange
                        ) {
                            shareViaSystem()
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .padding(.top)
            .navigationTitle("common.share".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await loadTemplates()
        }
    }

    /// Load templates from PostcardsManager (cached or from API)
    private func loadTemplates() async {
        isLoadingTemplates = true
        await postcardsManager.ensureTemplatesLoaded()
        isLoadingTemplates = false
        // Reset selection if current index is out of bounds
        if selectedStyleIndex >= templates.count && !templates.isEmpty {
            selectedStyleIndex = 0
        }
    }

    @MainActor
    private func renderShareCard() -> UIImage? {
        guard !templates.isEmpty && selectedStyleIndex < templates.count else {
            return nil
        }
        let template = templates[selectedStyleIndex]
        let cardView = ShareCardPreview(post: post, template: template)
            .frame(width: 300, height: 400)

        let renderer = ImageRenderer(content: cardView)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }

    private func saveAsImage() {
        if let image = renderShareCard() {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        Task {
            await manager.sharePost(post.id)
        }
        dismiss()
    }

    private func copyText() {
        UIPasteboard.general.string = manager.generateShareText(for: post)
        Task {
            await manager.sharePost(post.id)
        }
        dismiss()
    }

    private func shareViaSystem() {
        var items: [Any] = [manager.generateShareText(for: post)]

        if let image = renderShareCard() {
            items.insert(image, at: 0)
        }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        Task {
            await manager.sharePost(post.id)
        }
        dismiss()
    }
}

// MARK: - Share Option Button

struct ShareOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Post Media Grid View

struct PostMediaGridView: View {
    let media: [PostMedia]
    @State private var selectedMediaIndex: Int?

    private var columns: [GridItem] {
        switch media.count {
        case 1:
            return [GridItem(.flexible())]
        case 2:
            return [GridItem(.flexible()), GridItem(.flexible())]
        default:
            return [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                mediaItemView(item, index: index)
            }
        }
        .fullScreenCover(item: $selectedMediaIndex.animation()) { index in
            MediaViewerView(media: media, initialIndex: index) {
                selectedMediaIndex = nil
            }
        }
    }

    @ViewBuilder
    private func mediaItemView(_ item: PostMedia, index: Int) -> some View {
        GeometryReader { geometry in
            ZStack {
                switch item.type {
                case .image:
                    AsyncImage(url: URL(string: item.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderView(systemImage: "photo")
                        default:
                            ProgressView()
                        }
                    }

                case .video:
                    AsyncImage(url: URL(string: item.thumbnailUrl ?? item.url)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            placeholderView(systemImage: "video")
                        }
                    }
                    .overlay {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(radius: 4)
                    }

                case .audio:
                    placeholderView(systemImage: "waveform")
                        .overlay {
                            VStack(spacing: 4) {
                                Image(systemName: "waveform")
                                    .font(.title)
                                    .foregroundColor(.white)
                                if let duration = item.duration {
                                    Text(formatDuration(duration))
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                            }
                        }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                selectedMediaIndex = index
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func placeholderView(systemImage: String) -> some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: systemImage)
                    .font(.title)
                    .foregroundColor(.secondary)
            }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Media Viewer

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

struct MediaViewerView: View {
    let media: [PostMedia]
    let initialIndex: Int
    let onDismiss: () -> Void

    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(media: [PostMedia], initialIndex: Int, onDismiss: @escaping () -> Void) {
        self.media = media
        self.initialIndex = initialIndex
        self.onDismiss = onDismiss
        _currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(media.enumerated()), id: \.element.id) { index, item in
                    mediaContent(item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))

            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()

                if media.count > 1 {
                    Text("\(currentIndex + 1) / \(media.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func mediaContent(_ item: PostMedia) -> some View {
        switch item.type {
        case .image:
            AsyncImage(url: URL(string: item.url)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                default:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }

        case .video, .audio:
            // TODO: Implement video/audio player
            VStack {
                Image(systemName: item.type == .video ? "video" : "waveform")
                    .font(.system(size: 64))
                    .foregroundColor(.white)
                Text("agora.mediaNotSupported".localized)
                    .foregroundColor(.white)
            }
        }
    }
}

