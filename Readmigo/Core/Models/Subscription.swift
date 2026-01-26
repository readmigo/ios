import Foundation

// MARK: - Feature Limits

struct FeatureLimits {
    // AI 使用限制
    static let freeAICallsPerDay = 5
    static let proAICallsPerDay = Int.max

    // 词汇限制
    static let freeVocabularyLimit = 50
    static let proVocabularyLimit = Int.max

    // 书籍限制
    static let freeBooksLimit = 10
    static let proBooksLimit = Int.max

    // 离线下载限制
    static let freeOfflineLimit = 0
    static let proOfflineLimit = 10
    static let premiumOfflineLimit = Int.max

    // 语音聊天限制 (分钟/月)
    static let freeVoiceChatMinutes = 0
    static let proVoiceChatMinutes = 30
    static let premiumVoiceChatMinutes = Int.max

    // 明信片模板
    static let freeTemplatesCount = 3
}

// MARK: - Feature Item

struct FeatureItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String
    let available: Bool

    static func == (lhs: FeatureItem, rhs: FeatureItem) -> Bool {
        lhs.name == rhs.name && lhs.icon == rhs.icon
    }
}

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "FREE"
    case pro = "PRO"
    case premium = "PREMIUM"

    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }

    var features: [FeatureItem] {
        switch self {
        case .free:
            return [
                FeatureItem(name: "Access to 10 free books", icon: "book.fill", available: true),
                FeatureItem(name: "Basic AI explanations (5/day)", icon: "brain", available: true),
                FeatureItem(name: "Vocabulary saving (50 words)", icon: "text.book.closed", available: true),
            ]
        case .pro:
            return [
                FeatureItem(name: "Full library access (200+ books)", icon: "books.vertical.fill", available: true),
                FeatureItem(name: "Unlimited AI explanations", icon: "brain", available: true),
                FeatureItem(name: "Unlimited vocabulary saving", icon: "text.book.closed", available: true),
                FeatureItem(name: "Smart spaced repetition", icon: "arrow.triangle.2.circlepath", available: true),
                FeatureItem(name: "Offline reading", icon: "arrow.down.circle.fill", available: true),
                FeatureItem(name: "Detailed reading statistics", icon: "chart.bar.fill", available: true),
                FeatureItem(name: "Voice chat with AI (30 min/month)", icon: "waveform", available: true),
                FeatureItem(name: "Vocabulary export", icon: "square.and.arrow.up", available: true),
            ]
        case .premium:
            return SubscriptionTier.pro.features + [
                FeatureItem(name: "Advanced AI (GPT-4, Claude)", icon: "sparkles", available: true),
                FeatureItem(name: "Unlimited voice chat", icon: "waveform.circle.fill", available: true),
                FeatureItem(name: "Video chat with AI", icon: "video.fill", available: true),
                FeatureItem(name: "Priority support", icon: "star.fill", available: true),
            ]
        }
    }

    var featureStrings: [String] {
        features.map { $0.name }
    }

    var lockedFeatures: [FeatureItem] {
        switch self {
        case .free:
            return SubscriptionTier.pro.features
        case .pro:
            return []
        case .premium:
            return []
        }
    }

    var icon: String {
        switch self {
        case .free: return "person.circle"
        case .pro: return "star.circle.fill"
        case .premium: return "crown.fill"
        }
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable {
    case active = "ACTIVE"
    case expired = "EXPIRED"
    case cancelled = "CANCELLED"
    case gracePeriod = "GRACE_PERIOD"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .expired: return "Expired"
        case .cancelled: return "Cancelled"
        case .gracePeriod: return "Grace Period"
        }
    }
}

// MARK: - Subscription State

struct SubscriptionState: Codable {
    let tier: SubscriptionTier
    let status: SubscriptionStatus
    let isActive: Bool
    let expiresAt: Date?
    let willRenew: Bool
    let originalTransactionId: String?
    let productId: String?
}

// MARK: - Subscription Product

struct SubscriptionProduct: Identifiable {
    let id: String
    let displayName: String
    let description: String
    let price: Decimal
    let displayPrice: String
    let period: SubscriptionPeriod
    let tier: SubscriptionTier

    // 免费试用相关
    var hasFreeTrial: Bool = false
    var freeTrialDays: Int = 0

    var pricePerMonth: String {
        switch period {
        case .monthly:
            return displayPrice
        case .yearly:
            let monthly = price / 12
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale.current
            return formatter.string(from: monthly as NSNumber) ?? displayPrice
        }
    }

    var savingsPercentage: Int {
        switch period {
        case .yearly:
            return 48
        default:
            return 0
        }
    }

    var savings: String? {
        switch period {
        case .yearly:
            return "Save \(savingsPercentage)%"
        default:
            return nil
        }
    }
}

enum SubscriptionPeriod: String {
    case monthly
    case yearly

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Backend Request/Response Models

struct VerifyReceiptRequest: Codable {
    let receiptData: String
    let productId: String
    let transactionId: String
}

struct VerifyReceiptResponse: Codable {
    let success: Bool
    let subscription: SubscriptionState?
    let message: String?
}

struct RestorePurchasesResponse: Codable {
    let success: Bool
    let subscription: SubscriptionState?
    let restoredCount: Int
    let message: String?
}

struct SubscriptionStatusResponse: Codable {
    let subscription: SubscriptionState
}

// MARK: - Usage Response

struct UsageResponse: Codable {
    let aiCallsToday: Int
    let vocabularyCount: Int
    let offlineDownloadCount: Int
    let voiceChatMinutesThisMonth: Int
    let booksReadCount: Int
}
