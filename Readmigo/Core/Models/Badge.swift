import Foundation
import SwiftUI

// MARK: - Badge Category

enum BadgeCategory: String, Codable, CaseIterable {
    case reading = "READING"
    case vocabulary = "VOCABULARY"
    case streak = "STREAK"
    case milestone = "MILESTONE"
    case social = "SOCIAL"

    var displayName: String {
        switch self {
        case .reading: return "Reading"
        case .vocabulary: return "Vocabulary"
        case .streak: return "Streak"
        case .milestone: return "Milestone"
        case .social: return "Social"
        }
    }

    var icon: String {
        switch self {
        case .reading: return "book.fill"
        case .vocabulary: return "text.book.closed.fill"
        case .streak: return "flame.fill"
        case .milestone: return "star.fill"
        case .social: return "person.2.fill"
        }
    }
}

// MARK: - Badge Tier

enum BadgeTier: String, Codable, CaseIterable {
    case bronze = "BRONZE"
    case silver = "SILVER"
    case gold = "GOLD"
    case platinum = "PLATINUM"

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    /// Legacy hex color string (for light mode compatibility)
    var color: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        }
    }

    /// Light mode hex color
    private var colorLight: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        }
    }

    /// Dark mode hex color (slightly brighter for visibility)
    private var colorDark: String {
        switch self {
        case .bronze: return "#D4905A"
        case .silver: return "#D8D8D8"
        case .gold: return "#FFE14D"
        case .platinum: return "#F0EFED"
        }
    }

    /// Dynamic color that adapts to color scheme
    var adaptiveColor: Color {
        Color(UIColor { traitCollection in
            let hex = traitCollection.userInterfaceStyle == .dark ? colorDark : colorLight
            return UIColor(hex: hex)
        })
    }

    /// Secondary gradient color (darker variant)
    var secondaryColor: Color {
        Color(UIColor { traitCollection in
            let hex: String
            switch (self, traitCollection.userInterfaceStyle == .dark) {
            case (.bronze, false): hex = "#8B4513"
            case (.bronze, true): hex = "#A05020"
            case (.silver, false): hex = "#808080"
            case (.silver, true): hex = "#A0A0A0"
            case (.gold, false): hex = "#FFA500"
            case (.gold, true): hex = "#FFB833"
            case (.platinum, false): hex = "#A0A0A0"
            case (.platinum, true): hex = "#C0C0C0"
            }
            return UIColor(hex: hex)
        })
    }
}

// MARK: - Badge Requirement

struct BadgeRequirement: Codable {
    let type: String
    let target: Int
    let description: String?
}

// MARK: - Badge

struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let iconUrl: String?
    let category: BadgeCategory
    let tier: BadgeTier
    let requirement: BadgeRequirement
    let sortOrder: Int?
}

// MARK: - User Badge (Earned)

struct UserBadge: Codable, Identifiable {
    let id: String
    let badge: Badge
    let earnedAt: Date
}

// MARK: - Badge Progress

struct BadgeProgress: Codable, Identifiable {
    let badge: Badge
    let currentValue: Int
    let targetValue: Int
    let progressPercent: Double

    var id: String { badge.id }

    var isComplete: Bool {
        currentValue >= targetValue
    }
}

// MARK: - Response Models

struct BadgesResponse: Codable {
    let badges: [Badge]
}

struct UserBadgesResponse: Codable {
    let badges: [UserBadge]
    let total: Int
}

struct BadgeProgressResponse: Codable {
    let progress: [BadgeProgress]
}
