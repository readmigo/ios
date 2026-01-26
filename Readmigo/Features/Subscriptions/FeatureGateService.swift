import Foundation
import SwiftUI

// MARK: - Feature Access Result

enum FeatureAccessResult {
    case allowed
    case allowedWithLimit(remaining: Int, limit: Int)
    case restricted(reason: RestrictionReason, feature: Feature, upgradeMessage: String)

    var isAllowed: Bool {
        switch self {
        case .allowed, .allowedWithLimit:
            return true
        case .restricted:
            return false
        }
    }

    var remaining: Int? {
        if case .allowedWithLimit(let remaining, _) = self {
            return remaining
        }
        return nil
    }

    var limit: Int? {
        if case .allowedWithLimit(_, let limit) = self {
            return limit
        }
        return nil
    }

    var upgradeMessage: String? {
        if case .restricted(_, _, let message) = self {
            return message
        }
        return nil
    }
}

enum RestrictionReason {
    case requiresSubscription
    case dailyLimitReached
    case monthlyLimitReached
    case limitReached
}

enum Feature: String, CaseIterable {
    case bookAccess = "book_access"
    case aiExplanation = "ai_explanation"
    case vocabularySaving = "vocabulary_saving"
    case offlineReading = "offline_reading"
    case spacedRepetition = "spaced_repetition"
    case voiceChat = "voice_chat"
    case videoChat = "video_chat"
    case advancedAI = "advanced_ai"
    case premiumTemplates = "premium_templates"
    case detailedStats = "detailed_stats"
    case vocabularyExport = "vocabulary_export"

    var displayName: String {
        switch self {
        case .bookAccess: return "Book Access"
        case .aiExplanation: return "AI Explanations"
        case .vocabularySaving: return "Vocabulary Saving"
        case .offlineReading: return "Offline Reading"
        case .spacedRepetition: return "Spaced Repetition"
        case .voiceChat: return "Voice Chat"
        case .videoChat: return "Video Chat"
        case .advancedAI: return "Advanced AI"
        case .premiumTemplates: return "Premium Templates"
        case .detailedStats: return "Detailed Statistics"
        case .vocabularyExport: return "Vocabulary Export"
        }
    }
}

// MARK: - Feature Gate Service

@MainActor
class FeatureGateService: ObservableObject {
    static let shared = FeatureGateService()

    private var subscriptionManager: SubscriptionManager {
        SubscriptionManager.shared
    }

    private var usageTracker: UsageTracker {
        UsageTracker.shared
    }

    private init() {}

    // MARK: - Book Access

    func canAccessBook(isFree: Bool) -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .pro || tier == .premium {
            return .allowed
        }

        if isFree {
            return .allowed
        }

        return .restricted(
            reason: .requiresSubscription,
            feature: .bookAccess,
            upgradeMessage: "Upgrade to Pro to access all 200+ books"
        )
    }

    // MARK: - AI Usage

    func canUseAI() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .pro || tier == .premium {
            return .allowed
        }

        let todayUsage = usageTracker.aiCallsToday
        let limit = FeatureLimits.freeAICallsPerDay

        if todayUsage >= limit {
            return .restricted(
                reason: .dailyLimitReached,
                feature: .aiExplanation,
                upgradeMessage: "You've used all \(limit) AI explanations today. Upgrade to Pro for unlimited access."
            )
        }

        return .allowedWithLimit(remaining: limit - todayUsage, limit: limit)
    }

    // MARK: - Vocabulary

    func canSaveVocabulary() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .pro || tier == .premium {
            return .allowed
        }

        let currentCount = usageTracker.vocabularyCount
        let limit = FeatureLimits.freeVocabularyLimit

        if currentCount >= limit {
            return .restricted(
                reason: .limitReached,
                feature: .vocabularySaving,
                upgradeMessage: "You've reached the \(limit) word limit. Upgrade to Pro for unlimited vocabulary."
            )
        }

        return .allowedWithLimit(remaining: limit - currentCount, limit: limit)
    }

    func canExportVocabulary() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .free {
            return .restricted(
                reason: .requiresSubscription,
                feature: .vocabularyExport,
                upgradeMessage: "Vocabulary export is a Pro feature."
            )
        }

        return .allowed
    }

    // MARK: - Offline Reading

    func canDownloadOffline() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .free {
            return .restricted(
                reason: .requiresSubscription,
                feature: .offlineReading,
                upgradeMessage: "Offline reading is a Pro feature. Upgrade to download books."
            )
        }

        let downloadedCount = usageTracker.offlineDownloadCount
        let limit = tier == .premium ? FeatureLimits.premiumOfflineLimit : FeatureLimits.proOfflineLimit

        if limit != Int.max && downloadedCount >= limit {
            return .restricted(
                reason: .limitReached,
                feature: .offlineReading,
                upgradeMessage: "You've reached the download limit of \(limit) books."
            )
        }

        if limit == Int.max {
            return .allowed
        }

        return .allowedWithLimit(remaining: limit - downloadedCount, limit: limit)
    }

    // MARK: - Spaced Repetition

    func canUseSpacedRepetition() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .free {
            return .restricted(
                reason: .requiresSubscription,
                feature: .spacedRepetition,
                upgradeMessage: "Spaced repetition is a Pro feature. Upgrade to unlock smart review."
            )
        }

        return .allowed
    }

    // MARK: - Voice Chat

    func canUseVoiceChat() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .free {
            return .restricted(
                reason: .requiresSubscription,
                feature: .voiceChat,
                upgradeMessage: "Voice chat is a Pro feature. Upgrade to practice speaking."
            )
        }

        if tier == .pro {
            let usedMinutes = usageTracker.voiceChatMinutesThisMonth
            let limit = FeatureLimits.proVoiceChatMinutes
            let remaining = limit - usedMinutes

            if remaining <= 0 {
                return .restricted(
                    reason: .monthlyLimitReached,
                    feature: .voiceChat,
                    upgradeMessage: "You've used all \(limit) minutes this month."
                )
            }

            return .allowedWithLimit(remaining: remaining, limit: limit)
        }

        return .allowed
    }

    // MARK: - Video Chat

    func canUseVideoChat() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier != .premium {
            return .restricted(
                reason: .requiresSubscription,
                feature: .videoChat,
                upgradeMessage: "Video chat is a Premium feature."
            )
        }

        return .allowed
    }

    // MARK: - Advanced AI

    func canUseAdvancedAI() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier != .premium {
            return .restricted(
                reason: .requiresSubscription,
                feature: .advancedAI,
                upgradeMessage: "Advanced AI (GPT-4, Claude) is a Premium feature."
            )
        }

        return .allowed
    }

    // MARK: - Templates

    func canAccessTemplate(isPremium: Bool) -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if !isPremium {
            return .allowed
        }

        if tier == .pro || tier == .premium {
            return .allowed
        }

        return .restricted(
            reason: .requiresSubscription,
            feature: .premiumTemplates,
            upgradeMessage: "This template requires Pro subscription."
        )
    }

    // MARK: - Detailed Stats

    func canViewDetailedStats() -> FeatureAccessResult {
        let tier = subscriptionManager.currentTier

        if tier == .free {
            return .restricted(
                reason: .requiresSubscription,
                feature: .detailedStats,
                upgradeMessage: "Detailed reading statistics is a Pro feature."
            )
        }

        return .allowed
    }
}
