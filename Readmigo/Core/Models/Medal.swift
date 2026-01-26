import Foundation
import SwiftUI

// MARK: - Medal Category (9 Categories)

enum MedalCategory: String, Codable, CaseIterable {
    case readingMilestone = "READING_MILESTONE"     // 阅读里程碑
    case readingStreak = "READING_STREAK"           // 阅读连续
    case vocabularyMaster = "VOCABULARY_MASTER"     // 词汇大师
    case bookConqueror = "BOOK_CONQUEROR"           // 书籍征服
    case literaryGenre = "LITERARY_GENRE"           // 文学流派
    case timeTraveler = "TIME_TRAVELER"             // 时间旅人
    case culturalExplorer = "CULTURAL_EXPLORER"     // 文化探索
    case limitedEdition = "LIMITED_EDITION"         // 限定版
    case legendary = "LEGENDARY"                     // 传奇

    var displayName: String {
        switch self {
        case .readingMilestone: return "medal.category.readingMilestone".localized
        case .readingStreak: return "medal.category.readingStreak".localized
        case .vocabularyMaster: return "medal.category.vocabularyMaster".localized
        case .bookConqueror: return "medal.category.bookConqueror".localized
        case .literaryGenre: return "medal.category.literaryGenre".localized
        case .timeTraveler: return "medal.category.timeTraveler".localized
        case .culturalExplorer: return "medal.category.culturalExplorer".localized
        case .limitedEdition: return "medal.category.limitedEdition".localized
        case .legendary: return "medal.category.legendary".localized
        }
    }

    var icon: String {
        switch self {
        case .readingMilestone: return "flag.fill"
        case .readingStreak: return "flame.fill"
        case .vocabularyMaster: return "text.book.closed.fill"
        case .bookConqueror: return "books.vertical.fill"
        case .literaryGenre: return "theatermasks.fill"
        case .timeTraveler: return "clock.fill"
        case .culturalExplorer: return "globe"
        case .limitedEdition: return "star.fill"
        case .legendary: return "crown.fill"
        }
    }

    var description: String {
        switch self {
        case .readingMilestone: return "medal.category.readingMilestone.desc".localized
        case .readingStreak: return "medal.category.readingStreak.desc".localized
        case .vocabularyMaster: return "medal.category.vocabularyMaster.desc".localized
        case .bookConqueror: return "medal.category.bookConqueror.desc".localized
        case .literaryGenre: return "medal.category.literaryGenre.desc".localized
        case .timeTraveler: return "medal.category.timeTraveler.desc".localized
        case .culturalExplorer: return "medal.category.culturalExplorer.desc".localized
        case .limitedEdition: return "medal.category.limitedEdition.desc".localized
        case .legendary: return "medal.category.legendary.desc".localized
        }
    }
}

// MARK: - Medal Rarity (5 Tiers)

enum MedalRarity: String, Codable, CaseIterable {
    case common = "COMMON"           // 普通 - 铜质
    case uncommon = "UNCOMMON"       // 稀有 - 银质
    case rare = "RARE"               // 珍稀 - 金质
    case epic = "EPIC"               // 史诗 - 白金
    case legendary = "LEGENDARY"     // 传奇 - 钻石

    var displayName: String {
        switch self {
        case .common: return "medal.rarity.common".localized
        case .uncommon: return "medal.rarity.uncommon".localized
        case .rare: return "medal.rarity.rare".localized
        case .epic: return "medal.rarity.epic".localized
        case .legendary: return "medal.rarity.legendary".localized
        }
    }

    var materialName: String {
        switch self {
        case .common: return "medal.material.copper".localized
        case .uncommon: return "medal.material.silver".localized
        case .rare: return "medal.material.gold".localized
        case .epic: return "medal.material.platinum".localized
        case .legendary: return "medal.material.diamond".localized
        }
    }

    // Primary color
    var color: Color {
        Color(UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            switch self {
            case .common:
                return UIColor(hex: isDark ? "#D4905A" : "#B87333")    // Copper
            case .uncommon:
                return UIColor(hex: isDark ? "#D8D8D8" : "#C0C0C0")    // Silver
            case .rare:
                return UIColor(hex: isDark ? "#FFE14D" : "#FFD700")    // Gold
            case .epic:
                return UIColor(hex: isDark ? "#C8A2FF" : "#9B5DE5")    // Purple/Platinum
            case .legendary:
                return UIColor(hex: isDark ? "#66D9FF" : "#00BBF9")    // Diamond Blue
            }
        })
    }

    // Secondary color for gradients
    var secondaryColor: Color {
        Color(UIColor { traitCollection in
            let isDark = traitCollection.userInterfaceStyle == .dark
            switch self {
            case .common:
                return UIColor(hex: isDark ? "#A05020" : "#8B4513")
            case .uncommon:
                return UIColor(hex: isDark ? "#A0A0A0" : "#808080")
            case .rare:
                return UIColor(hex: isDark ? "#FFB833" : "#FFA500")
            case .epic:
                return UIColor(hex: isDark ? "#7B2EFF" : "#6B21A8")
            case .legendary:
                return UIColor(hex: isDark ? "#00A3CC" : "#0077B6")
            }
        })
    }

    // Gradient for medal background
    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, secondaryColor],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Glow color for effects
    var glowColor: Color {
        switch self {
        case .common: return Color(hex: "#B87333").opacity(0.3)
        case .uncommon: return Color(hex: "#C0C0C0").opacity(0.4)
        case .rare: return Color(hex: "#FFD700").opacity(0.5)
        case .epic: return Color(hex: "#9B5DE5").opacity(0.6)
        case .legendary: return Color(hex: "#00BBF9").opacity(0.7)
        }
    }

    // Unlock percentage (global)
    var unlockPercentage: Double {
        switch self {
        case .common: return 30.0
        case .uncommon: return 25.0
        case .rare: return 25.0
        case .epic: return 15.0
        case .legendary: return 5.0
        }
    }
}

// MARK: - Medal Unlock Type

enum MedalUnlockType: String, Codable {
    case readingDuration = "READING_DURATION"       // 累计阅读时长
    case readingStreak = "READING_STREAK"           // 连续阅读天数
    case vocabularyCount = "VOCABULARY_COUNT"       // 词汇量
    case bookCompleted = "BOOK_COMPLETED"           // 完成书籍数
    case genreReading = "GENRE_READING"             // 特定类型阅读时长
    case timeBased = "TIME_BASED"                   // 特定时间阅读
    case culturalReading = "CULTURAL_READING"       // 文化类阅读
    case composite = "COMPOSITE"                    // 复合条件
    case manual = "MANUAL"                          // 手动发放（活动等）
}

// MARK: - Medal Unlock Condition

struct MedalUnlockCondition: Codable {
    let type: MedalUnlockType
    let threshold: Int
    let additionalConditions: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case type
        case threshold
        case additionalConditions
    }
}

// MARK: - Medal Definition

struct Medal: Codable, Identifiable, Hashable {
    let id: String
    let code: String                  // Unique code like "READING_MILESTONE_1"
    let nameZh: String
    let nameEn: String
    let descriptionZh: String
    let descriptionEn: String
    let category: MedalCategory
    let rarity: MedalRarity
    let unlockType: MedalUnlockType
    let unlockThreshold: Int
    let unlockConditions: [String: AnyCodableValue]?
    let iconUrl: String?
    let model3dUrl: String?
    let materialPreset: String?
    let designStory: String?
    let displayOrder: Int
    let isActive: Bool
    let isLimited: Bool
    let limitedStartAt: Date?
    let limitedEndAt: Date?

    // Localized name based on current locale
    var name: String {
        Locale.current.language.languageCode?.identifier == "zh" ? nameZh : nameEn
    }

    // Localized description
    var localizedDescription: String {
        Locale.current.language.languageCode?.identifier == "zh" ? descriptionZh : descriptionEn
    }

    // For Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Medal, rhs: Medal) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - User Medal (Earned)

struct UserMedal: Codable, Identifiable {
    let id: String
    let userId: String
    let medalId: String
    let medal: Medal
    let unlockedAt: Date
    let unlockedValue: Int?
    let isDisplayed: Bool
    let displayOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId
        case medalId
        case medal
        case unlockedAt
        case unlockedValue
        case isDisplayed
        case displayOrder
    }
}

// MARK: - Medal Progress

struct MedalProgress: Codable, Identifiable {
    let medalCode: String
    let currentValue: Int
    let targetValue: Int
    let lastUpdatedAt: Date?

    var id: String { medalCode }

    var percentage: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, Double(currentValue) / Double(targetValue))
    }

    var percentageInt: Int {
        Int(percentage * 100)
    }

    var isComplete: Bool {
        currentValue >= targetValue
    }
}

// MARK: - Medal Statistics

struct MedalStats: Codable {
    let totalUnlocked: Int
    let totalMedals: Int
    let byRarity: [String: Int]
    let byCategory: [String: Int]

    var unlockedPercentage: Double {
        guard totalMedals > 0 else { return 0 }
        return Double(totalUnlocked) / Double(totalMedals)
    }
}

// MARK: - API Response Models

struct MedalsResponse: Codable {
    let medals: [Medal]
    let categories: [String]?
}

struct UserMedalsResponse: Codable {
    let unlocked: [UserMedal]
    let progress: [MedalProgress]
    let stats: MedalStats
}

struct MedalDetailResponse: Codable {
    let medal: Medal
    let userStatus: MedalUserStatus
    let globalStats: MedalGlobalStats
}

struct MedalUserStatus: Codable {
    let isUnlocked: Bool
    let unlockedAt: Date?
    let progress: MedalProgressDetail?
}

struct MedalProgressDetail: Codable {
    let current: Int
    let target: Int
    let percentage: Double
}

struct MedalGlobalStats: Codable {
    let totalUnlocked: Int
    let unlockRate: Double
}

struct CheckMedalsResponse: Codable {
    let newlyUnlocked: [UserMedal]
    let updatedProgress: [MedalProgress]
}

struct SetDisplayMedalsRequest: Codable {
    let medalIds: [String]
}

// MARK: - AnyCodableValue (For flexible JSON)

struct AnyCodableValue: Codable, Hashable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodableValue].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodableValue].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }

    func hash(into hasher: inout Hasher) {
        if let int = value as? Int {
            hasher.combine(int)
        } else if let double = value as? Double {
            hasher.combine(double)
        } else if let string = value as? String {
            hasher.combine(string)
        } else if let bool = value as? Bool {
            hasher.combine(bool)
        }
    }

    static func == (lhs: AnyCodableValue, rhs: AnyCodableValue) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Int, r as Int): return l == r
        case let (l as Double, r as Double): return l == r
        case let (l as String, r as String): return l == r
        case let (l as Bool, r as Bool): return l == r
        default: return false
        }
    }
}

// MARK: - Medal Material Spec (For 3D Rendering)

struct MedalMaterialSpec {
    let baseColor: Color
    let metallicness: Float
    let roughness: Float
    let specularIntensity: Float
    let environmentReflection: Float
    let normalMapIntensity: Float
    let gradientOverlay: [Color]?
    let refractionIndex: Float?
    let rainbowDispersion: Bool
    let particleEffect: MedalParticleEffect?

    static func material(for rarity: MedalRarity) -> MedalMaterialSpec {
        switch rarity {
        case .common:
            return MedalMaterialSpec(
                baseColor: Color(hex: "#B87333"),
                metallicness: 0.85,
                roughness: 0.35,
                specularIntensity: 0.6,
                environmentReflection: 0.3,
                normalMapIntensity: 0.8,
                gradientOverlay: nil,
                refractionIndex: nil,
                rainbowDispersion: false,
                particleEffect: nil
            )
        case .uncommon:
            return MedalMaterialSpec(
                baseColor: Color(hex: "#C0C0C0"),
                metallicness: 0.95,
                roughness: 0.15,
                specularIntensity: 0.9,
                environmentReflection: 0.5,
                normalMapIntensity: 0.7,
                gradientOverlay: nil,
                refractionIndex: nil,
                rainbowDispersion: false,
                particleEffect: nil
            )
        case .rare:
            return MedalMaterialSpec(
                baseColor: Color(hex: "#FFD700"),
                metallicness: 1.0,
                roughness: 0.1,
                specularIntensity: 1.0,
                environmentReflection: 0.7,
                normalMapIntensity: 0.6,
                gradientOverlay: nil,
                refractionIndex: nil,
                rainbowDispersion: false,
                particleEffect: nil
            )
        case .epic:
            return MedalMaterialSpec(
                baseColor: Color(hex: "#E5E4E2"),
                metallicness: 1.0,
                roughness: 0.05,
                specularIntensity: 1.2,
                environmentReflection: 0.85,
                normalMapIntensity: 0.5,
                gradientOverlay: [
                    Color(hex: "#E5E4E2"),
                    Color(hex: "#9B5DE5"),
                    Color(hex: "#00BBF9")
                ],
                refractionIndex: nil,
                rainbowDispersion: false,
                particleEffect: .glow
            )
        case .legendary:
            return MedalMaterialSpec(
                baseColor: Color(hex: "#B9F2FF"),
                metallicness: 1.0,
                roughness: 0.0,
                specularIntensity: 1.5,
                environmentReflection: 1.0,
                normalMapIntensity: 0.3,
                gradientOverlay: nil,
                refractionIndex: 2.42,  // Diamond refraction index
                rainbowDispersion: true,
                particleEffect: .sparkle
            )
        }
    }
}

enum MedalParticleEffect: String, Codable {
    case sparkle    // 闪烁
    case glow       // 光晕
    case fire       // 火焰
    case stars      // 星尘
}
