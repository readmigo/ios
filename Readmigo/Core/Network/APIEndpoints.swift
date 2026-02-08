import Foundation

enum APIEndpoints {
    // Version
    static let versionCheck = "/version/check"
    static let versionInfo = "/version"
    static let versionManifest = "/version/manifest"
    static let versionContext = "/version/context"
    static let versionContentLimits = "/version/content-limits"
    static func versionManifestForMajor(_ majorVersion: Int) -> String { "/version/manifest/\(majorVersion)" }
    static func versionFeatureCheck(_ feature: String) -> String { "/version/features/\(feature)" }

    // Auth
    static let authApple = "/auth/apple"
    static let authGoogle = "/auth/google"
    static let authRefresh = "/auth/refresh"
    static let authRegister = "/auth/register"
    static let authLogin = "/auth/login"
    static let authForgotPassword = "/auth/forgot-password"
    static let authResetPassword = "/auth/reset-password"
    static let authVerifyEmail = "/auth/verify-email"
    static let authResendVerification = "/auth/resend-verification"

    // Users
    static let userMe = "/users/me"
    static let userAssessment = "/users/me/assessment"
    static let deleteAccount = "/users/me"

    // Books
    static let books = "/books"
    static func book(_ id: String) -> String { "/books/\(id)" }
    static func bookDetail(_ id: String) -> String { "/books/\(id)" }
    static func bookContent(_ bookId: String, _ chapterId: String) -> String {
        "/books/\(bookId)/content/\(chapterId)"
    }
    static func bookContext(_ bookId: String) -> String { "/books/\(bookId)/context" }
    static func bookReadingGuide(_ bookId: String) -> String { "/books/\(bookId)/reading-guide" }
    static let bookRecommendations = "/books/recommendations"
    static let bookGenres = "/books/genres"

    // Reading
    static let readingLibrary = "/reading/library"
    static func readingProgress(_ bookId: String) -> String { "/reading/progress/\(bookId)" }
    static func updateProgress(_ bookId: String) -> String { "/reading/progress/\(bookId)" }
    static let readingSessions = "/reading/sessions"
    static let readingStats = "/reading/stats"
    static let readingCurrent = "/reading/current"
    static let recommendations = "/books/recommendations"
    static let addToLibrary = "/reading/library"
    static func removeFromLibrary(_ bookId: String) -> String { "/reading/library/\(bookId)" }
    static func updateBookStatus(_ bookId: String) -> String { "/reading/library/\(bookId)/status" }

    // AI
    static let aiExplain = "/ai/explain"
    static let aiExplainStream = "/ai/explain/stream"
    static let aiSimplify = "/ai/simplify"
    static let aiTranslate = "/ai/translate"
    static let aiQA = "/ai/qa"
    static let aiQAStream = "/ai/qa/stream"
    static let aiUsage = "/ai/usage"

    // Vocabulary
    static let vocabulary = "/vocabulary"
    static func vocabularyItem(_ id: String) -> String { "/vocabulary/\(id)" }
    static let vocabularyReview = "/vocabulary/review"
    static func vocabularyReviewItem(_ id: String) -> String { "/vocabulary/\(id)/review" }
    static let vocabularyReviewBatch = "/vocabulary/review/batch"
    static let vocabularyStats = "/vocabulary/stats"

    // Quotes
    static let quotes = "/quotes"
    static let quotesDaily = "/quotes/daily"
    static let quotesTrending = "/quotes/trending"
    static let quotesFavorites = "/quotes/favorites"
    static let quotesRandom = "/quotes/random"
    static let quotesTags = "/quotes/tags"
    static let quotesAuthors = "/quotes/authors"
    static func quote(_ id: String) -> String { "/quotes/\(id)" }
    static func quoteLike(_ id: String) -> String { "/quotes/\(id)/like" }
    static func quotesBook(_ bookId: String) -> String { "/quotes/book/\(bookId)" }
    static func quotesAuthor(_ author: String) -> String { "/quotes/author/\(author)" }

    // Badges
    static let badges = "/badges"
    static let badgesUser = "/badges/user"
    static let badgesProgress = "/badges/progress"
    static func badge(_ id: String) -> String { "/badges/\(id)" }

    // BookLists
    static let booklists = "/booklists"
    static let booklistsFeatured = "/booklists/featured"
    static let booklistsAIPersonalized = "/booklists/ai-personalized"
    static func booklist(_ id: String) -> String { "/booklists/\(id)" }

    // Categories
    static let categories = "/categories"
    static let categoriesTree = "/categories/tree"
    static let categoriesRoot = "/categories/root"
    static let categoriesCascade = "/categories/cascade"
    static func category(_ id: String) -> String { "/categories/\(id)" }
    static func categoryBySlug(_ slug: String) -> String { "/categories/slug/\(slug)" }
    static func categoryChildren(_ id: String) -> String { "/categories/\(id)/children" }
    static func categoryBooks(_ id: String) -> String { "/categories/\(id)/books" }
    static func categoriesCascadeWithPath(_ path: String) -> String { "/categories/cascade?path=\(path)" }

    // Analytics
    static let analyticsOverview = "/analytics/overview"
    static let analyticsDaily = "/analytics/daily"
    static let analyticsReadingTrend = "/analytics/reading-trend"
    static let analyticsVocabularyProgress = "/analytics/vocabulary-progress"
    static let analyticsReadingProgress = "/analytics/reading-progress"

    // Subscriptions
    static let subscriptionsStatus = "/subscriptions/status"
    static let subscriptionsVerify = "/subscriptions/verify"
    static let subscriptionsRestore = "/subscriptions/restore"

    // Usage
    static let usageCurrent = "/usage/current"
    static let usageAI = "/usage/ai"
    static let usageVoiceChat = "/usage/voice-chat"

    // Postcards
    static let postcards = "/postcards"
    static let postcardsMine = "/postcards/mine"
    static let postcardsCreate = "/postcards"
    static let postcardTemplates = "/postcards/templates"
    static func postcard(_ id: String) -> String { "/postcards/\(id)" }
    static func postcardShare(_ id: String) -> String { "/postcards/\(id)/share" }

    // Logs
    static let logsBatch = "/logs/batch"
    static let logsCrash = "/logs/crash"
    static let runtimeLogsBatch = "/logs/runtime/batch"

    // Agora (城邦)
    static let agoraPosts = "/agora/posts"
    static let agoraMediaUpload = "/agora/media/upload"
    static let agoraAuthors = "/agora/authors"
    static let agoraBlocked = "/agora/blocked"
    static func agoraPost(_ id: String) -> String { "/agora/posts/\(id)" }
    static func agoraPostLike(_ id: String) -> String { "/agora/posts/\(id)/like" }
    static func agoraPostComments(_ id: String) -> String { "/agora/posts/\(id)/comments" }
    static func agoraPostShare(_ id: String) -> String { "/agora/posts/\(id)/share" }
    static func agoraPostHide(_ id: String) -> String { "/agora/posts/\(id)/hide" }
    static func agoraPostReport(_ id: String) -> String { "/agora/posts/\(id)/report" }
    static func agoraCommentLike(_ id: String) -> String { "/agora/comments/\(id)/like" }
    static func agoraComment(_ id: String) -> String { "/agora/comments/\(id)" }
    static func agoraAuthor(_ id: String) -> String { "/agora/authors/\(id)" }
    static func agoraAuthorBlock(_ id: String) -> String { "/agora/authors/\(id)/block" }

    // Authors
    static let authors = "/authors"
    static let authorsSearch = "/authors/search"
    static let authorsFollowing = "/authors/following"
    static func author(_ id: String) -> String { "/authors/\(id)" }
    static func authorRelated(_ id: String) -> String { "/authors/\(id)/related" }
    static func authorReadingProgress(_ id: String) -> String { "/authors/\(id)/reading-progress" }
    static func authorFollow(_ id: String) -> String { "/authors/\(id)/follow" }

    // Author Chat
    static let authorChatSessions = "/author-chat/sessions"
    static func authorChatSession(_ id: String) -> String { "/author-chat/sessions/\(id)" }
    static func authorChatMessages(_ sessionId: String) -> String { "/author-chat/sessions/\(sessionId)/messages" }
    static func authorChatMessagesStream(_ sessionId: String) -> String { "/author-chat/sessions/\(sessionId)/messages/stream" }
    static func authorChatMessageRate(_ messageId: String) -> String { "/author-chat/messages/\(messageId)/rate" }

    // Voice Chat
    static let voiceChatUsage = "/author-chat/voice/usage"
    static let voiceChatVoices = "/author-chat/voice/voices"
    static let voiceChatTranscribe = "/author-chat/voice/transcribe"
    static func voiceChatSynthesize(_ authorId: String) -> String { "/author-chat/voice/synthesize/\(authorId)" }
    static func voiceChatChat(_ sessionId: String) -> String { "/author-chat/voice/chat/\(sessionId)" }

    // Video Chat
    static let videoChatUsage = "/author-chat/video/usage"
    static let videoChatAvatars = "/author-chat/video/avatars"
    static func videoChatAvailable(_ authorId: String) -> String { "/author-chat/video/available/\(authorId)" }
    static func videoChatGenerate(_ authorId: String) -> String { "/author-chat/video/generate/\(authorId)" }
    static func videoChatChat(_ sessionId: String) -> String { "/author-chat/video/chat/\(sessionId)" }
    static func videoChatStatus(_ videoId: String) -> String { "/author-chat/video/status/\(videoId)" }

    // Annual Report
    static func annualReport(_ year: Int) -> String { "/annual-report/\(year)" }
    static func annualReportStatus(_ year: Int) -> String { "/annual-report/\(year)/status" }
    static let annualReportHistory = "/annual-report/history"
    static func annualReportRegenerate(_ year: Int) -> String { "/annual-report/\(year)/regenerate" }
    static func annualReportSharePage(_ year: Int) -> String { "/annual-report/\(year)/share-page" }
    static func annualReportShare(_ year: Int) -> String { "/annual-report/\(year)/share" }

    // Messaging (In-App Messages)
    static let messageThreads = "/messages/threads"
    static let messageUnreadCount = "/messages/unread-count"
    static let messageAttachments = "/messages/attachments"
    static func messageThread(_ id: String) -> String { "/messages/threads/\(id)" }
    static func messageThreadMessages(_ threadId: String) -> String { "/messages/threads/\(threadId)/messages" }
    static func messageThreadClose(_ threadId: String) -> String { "/messages/threads/\(threadId)/close" }
    static func messageThreadRead(_ threadId: String) -> String { "/messages/threads/\(threadId)/read" }
    static func messageThreadRating(_ threadId: String) -> String { "/messages/threads/\(threadId)/rating" }
    static func messageAttachment(_ id: String) -> String { "/messages/attachments/\(id)" }

    // Guest Feedback (No Auth Required)
    static let guestFeedback = "/guest-feedback"
    static let guestFeedbackPushToken = "/guest-feedback/push-token"
    static func guestFeedbackByDevice(_ deviceId: String) -> String { "/guest-feedback/device/\(deviceId)" }
    static func guestFeedbackDetail(_ id: String, deviceId: String) -> String { "/guest-feedback/\(id)/device/\(deviceId)" }

    // Audiobooks
    static let audiobooks = "/audiobooks"
    static let audiobooksLanguages = "/audiobooks/languages"
    static let audiobooksRecentlyListened = "/audiobooks/recently-listened"
    static let audiobooksPopular = "/audiobooks/popular"
    static func audiobook(_ id: String) -> String { "/audiobooks/\(id)" }
    static func audiobookForBook(_ bookId: String) -> String { "/audiobooks/book/\(bookId)" }
    static func audiobookWithProgress(_ id: String) -> String { "/audiobooks/\(id)/with-progress" }
    static func audiobookProgress(_ id: String) -> String { "/audiobooks/\(id)/progress" }
    static func audiobookStart(_ id: String) -> String { "/audiobooks/\(id)/start" }

    // Sync (Whispersync)
    static let syncProgress = "/sync/progress"

    // User Books (Import)
    static let userBooks = "/user-books"
    static let userBooksQuota = "/user-books/quota"
    static let userBooksImportInitiate = "/user-books/import/initiate"
    static let userBooksImportComplete = "/user-books/import/complete"
    static func userBooksImportStatus(_ jobId: String) -> String { "/user-books/import/\(jobId)/status" }
    static func userBooksImported(_ bookId: String) -> String { "/user-books/imported/\(bookId)" }

    // Devices
    static let devices = "/devices"
    static let devicesStats = "/devices/stats"
    static let devicesRegister = "/devices/register"
    static let devicesLogoutOthers = "/devices/logout-others"
    static let devicesCheckLogout = "/devices/check-logout"
    static func device(_ deviceId: String) -> String { "/devices/\(deviceId)" }
    static func deviceLogout(_ deviceId: String) -> String { "/devices/\(deviceId)/logout" }
    static func devicePrimary(_ deviceId: String) -> String { "/devices/\(deviceId)/primary" }

    // FAQ
    static let faq = "/faq"
    static let faqFeatured = "/faq/featured"
    static let faqPopular = "/faq/popular"
    static let faqSearch = "/faq/search"
    static let faqFeedback = "/faq/feedback"
    static func faqCategory(_ categoryId: String) -> String { "/faq/category/\(categoryId)" }
    static func faqDetail(_ id: String) -> String { "/faq/\(id)" }

    // Medals
    static let medals = "/medals"
    static let medalsUser = "/medals/user"
    static let medalsUserStats = "/medals/user/stats"
    static let medalsUserProgress = "/medals/user/progress"
    static let medalsUserWithProgress = "/medals/user/with-progress"
    static let medalsUserInProgress = "/medals/user/in-progress"
    static let medalsUserDisplayed = "/medals/user/displayed"
    static let medalsUserCheck = "/medals/user/check"
    static func medalDetail(_ id: String) -> String { "/medals/detail/\(id)" }
    static func medalShare(_ id: String) -> String { "/medals/user/\(id)/share" }

    // Performance Metrics
    static let metricsClient = "/metrics/client"
    static let metricsException = "/metrics/exception"

    // Browsing History
    static let browsingHistory = "/browsing-history"
    static func browsingHistoryItem(_ bookId: String) -> String { "/browsing-history/\(bookId)" }
    static let browsingHistoryBatchDelete = "/browsing-history/batch-delete"
    static let browsingHistoryReorder = "/browsing-history/reorder"
    static let browsingHistorySync = "/browsing-history/sync"

    // Chapter Text (plain text paragraphs for TTS)
    static func chapterText(_ bookId: String, _ chapterId: String) -> String {
        "/books/\(bookId)/chapters/\(chapterId)/text"
    }

    // Chapter Translations
    static func chapterTranslationAvailable(_ bookId: String, _ chapterId: String) -> String {
        "/books/\(bookId)/chapters/\(chapterId)/translations/available"
    }
    static func chapterTranslationMetadata(_ bookId: String, _ chapterId: String, _ locale: String) -> String {
        "/books/\(bookId)/chapters/\(chapterId)/translations/\(locale)/metadata"
    }
    static func paragraphTranslation(_ bookId: String, _ chapterId: String, _ locale: String, _ paragraphIndex: Int) -> String {
        "/books/\(bookId)/chapters/\(chapterId)/translations/\(locale)/paragraphs/\(paragraphIndex)"
    }
    static func batchParagraphTranslations(_ bookId: String, _ chapterId: String, _ locale: String) -> String {
        "/books/\(bookId)/chapters/\(chapterId)/translations/\(locale)/paragraphs"
    }

    // Favorites
    static let favorites = "/favorites"
    static func favoriteItem(_ bookId: String) -> String { "/favorites/\(bookId)" }
    static let favoritesBatchDelete = "/favorites/batch-delete"
    static func favoriteCheck(_ bookId: String) -> String { "/favorites/\(bookId)/check" }
}
