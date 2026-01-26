import Foundation
import SwiftUI

// MARK: - Postcard

struct Postcard: Identifiable, Codable {
    let id: String
    let userId: String
    let templateId: String
    let quote: PostcardQuote?
    let customText: String?
    let imageUrl: String?
    let backgroundColor: String?
    let textColor: String?
    let fontFamily: String?
    let isPublic: Bool
    let shareCount: Int
    let createdAt: Date
    let updatedAt: Date

    var displayText: String {
        customText ?? quote?.text ?? ""
    }

    var bgColor: Color {
        if let hex = backgroundColor {
            return Color(hex: hex)
        }
        return .white
    }

    var txtColor: Color {
        if let hex = textColor {
            return Color(hex: hex)
        }
        return .black
    }
}

// MARK: - Postcard Quote

struct PostcardQuote: Codable {
    let id: String
    let text: String
    let author: String?
    let source: String?
}

// MARK: - Postcard Template
// Matches backend API response from /postcards/templates

struct PostcardTemplate: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let previewUrl: String?
    let backgroundColor: String
    let fontFamily: String
    let fontColor: String
    let isPremium: Bool
    let isAvailable: Bool?

    // Optional fields for extended template data
    let category: TemplateCategory?
    let sortOrder: Int?
    let secondaryColor: String?
    let decorationIcon: String?
    let gradientColors: [String]?

    // MARK: - Coding Keys (to handle both API formats)

    enum CodingKeys: String, CodingKey {
        case id, name, previewUrl, backgroundColor, fontFamily, fontColor
        case isPremium, isAvailable, category, sortOrder
        case secondaryColor, decorationIcon, gradientColors
    }

    // MARK: - Computed Properties

    var bgColor: Color {
        Color(hex: backgroundColor)
    }

    var txtColor: Color {
        Color(hex: fontColor)
    }

    var secondaryTxtColor: Color {
        if let secondary = secondaryColor {
            return Color(hex: secondary)
        }
        // Generate a lighter/darker version of fontColor
        return txtColor.opacity(0.7)
    }

    var gradientColorValues: [Color] {
        gradientColors?.map { Color(hex: $0) } ?? []
    }

    var usesGradient: Bool {
        !(gradientColors?.isEmpty ?? true)
    }

    var displayName: String {
        // Localize template name
        let key = "share.style.\(name.lowercased())"
        let localized = key.localized
        return localized != key ? localized : name
    }

    var quoteFont: Font {
        // Map font family to iOS fonts
        switch fontFamily.lowercased() {
        case "merriweather", "georgia", "lora", "cormorant", "playfair display":
            return .custom("Georgia", size: 17)
        case "roboto", "inter", "poppins", "quicksand":
            return .system(size: 17, weight: .medium, design: .default)
        default:
            return .system(size: 17)
        }
    }

    var sfSymbolIcon: String? {
        // Map template name to SF Symbol
        if let icon = decorationIcon {
            return icon
        }
        switch name.lowercased() {
        case "vintage": return "seal.fill"
        case "nature": return "leaf.fill"
        case "elegant": return "sparkles"
        case "ocean": return "drop.fill"
        case "sunset": return "sun.max.fill"
        case "literary": return "book.closed.fill"
        default: return nil
        }
    }

    var decorationColor: Color {
        if let secondary = secondaryColor {
            return Color(hex: secondary).opacity(0.3)
        }
        // Generate decoration color based on background
        return bgColor.opacity(0.3)
    }

    // MARK: - Equatable

    static func == (lhs: PostcardTemplate, rhs: PostcardTemplate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Template Category

enum TemplateCategory: String, Codable, CaseIterable {
    case minimal = "MINIMAL"
    case nature = "NATURE"
    case literary = "LITERARY"
    case vintage = "VINTAGE"
    case modern = "MODERN"
    case artistic = "ARTISTIC"
    case seasonal = "SEASONAL"
    case classic = "CLASSIC"
    case elegant = "ELEGANT"
    case ocean = "OCEAN"
    case sunset = "SUNSET"
    case gradient = "GRADIENT"
    case polaroid = "POLAROID"

    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .nature: return "Nature"
        case .literary: return "Literary"
        case .vintage: return "Vintage"
        case .modern: return "Modern"
        case .artistic: return "Artistic"
        case .seasonal: return "Seasonal"
        case .classic: return "Classic"
        case .elegant: return "Elegant"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .gradient: return "Gradient"
        case .polaroid: return "Polaroid"
        }
    }

    var icon: String {
        switch self {
        case .minimal: return "square"
        case .nature: return "leaf"
        case .literary: return "text.book.closed"
        case .vintage: return "clock"
        case .modern: return "sparkles"
        case .artistic: return "paintbrush"
        case .seasonal: return "snowflake"
        case .classic: return "textformat"
        case .elegant: return "crown"
        case .ocean: return "drop"
        case .sunset: return "sun.max"
        case .gradient: return "rectangle.fill"
        case .polaroid: return "camera"
        }
    }
}

// MARK: - Default Templates (Fallback for offline)

extension PostcardTemplate {
    static let defaultTemplates: [PostcardTemplate] = [
        PostcardTemplate(
            id: "template-classic",
            name: "Classic",
            previewUrl: nil,
            backgroundColor: "#FFFFFF",
            fontFamily: "Merriweather",
            fontColor: "#333333",
            isPremium: false,
            isAvailable: true,
            category: .classic,
            sortOrder: 0,
            secondaryColor: "#666666",
            decorationIcon: nil,
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-vintage",
            name: "Vintage",
            previewUrl: nil,
            backgroundColor: "#F5E6D3",
            fontFamily: "Playfair Display",
            fontColor: "#5D4037",
            isPremium: false,
            isAvailable: true,
            category: .vintage,
            sortOrder: 1,
            secondaryColor: "#795548",
            decorationIcon: "seal.fill",
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-modern",
            name: "Modern",
            previewUrl: nil,
            backgroundColor: "#1A1A2E",
            fontFamily: "Inter",
            fontColor: "#FFFFFF",
            isPremium: false,
            isAvailable: true,
            category: .modern,
            sortOrder: 2,
            secondaryColor: "#CCCCCC",
            decorationIcon: nil,
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-nature",
            name: "Nature",
            previewUrl: nil,
            backgroundColor: "#E8F5E9",
            fontFamily: "Lora",
            fontColor: "#2E7D32",
            isPremium: false,
            isAvailable: true,
            category: .nature,
            sortOrder: 3,
            secondaryColor: "#558B2F",
            decorationIcon: "leaf.fill",
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-elegant",
            name: "Elegant",
            previewUrl: nil,
            backgroundColor: "#FFF8E1",
            fontFamily: "Cormorant",
            fontColor: "#6D4C41",
            isPremium: true,
            isAvailable: nil,
            category: .elegant,
            sortOrder: 4,
            secondaryColor: "#8D6E63",
            decorationIcon: "sparkles",
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-minimal",
            name: "Minimal",
            previewUrl: nil,
            backgroundColor: "#FAFAFA",
            fontFamily: "Roboto",
            fontColor: "#212121",
            isPremium: true,
            isAvailable: nil,
            category: .minimal,
            sortOrder: 5,
            secondaryColor: "#616161",
            decorationIcon: nil,
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-ocean",
            name: "Ocean",
            previewUrl: nil,
            backgroundColor: "#E3F2FD",
            fontFamily: "Quicksand",
            fontColor: "#1565C0",
            isPremium: true,
            isAvailable: nil,
            category: .ocean,
            sortOrder: 6,
            secondaryColor: "#1976D2",
            decorationIcon: "drop.fill",
            gradientColors: nil
        ),
        PostcardTemplate(
            id: "template-sunset",
            name: "Sunset",
            previewUrl: nil,
            backgroundColor: "#FFF3E0",
            fontFamily: "Poppins",
            fontColor: "#E65100",
            isPremium: true,
            isAvailable: nil,
            category: .sunset,
            sortOrder: 7,
            secondaryColor: "#F57C00",
            decorationIcon: "sun.max.fill",
            gradientColors: nil
        ),
    ]
}

// MARK: - Create Postcard Request

struct CreatePostcardRequest: Codable {
    let templateId: String
    let quoteId: String?
    let customText: String?
    let backgroundColor: String?
    let textColor: String?
    let fontFamily: String?
    let isPublic: Bool
}

// MARK: - Update Postcard Request

struct UpdatePostcardRequest: Codable {
    let customText: String?
    let backgroundColor: String?
    let textColor: String?
    let fontFamily: String?
    let isPublic: Bool?
}

// MARK: - Share Postcard Request

struct SharePostcardRequest: Codable {
    let platform: SharePlatform
}

enum SharePlatform: String, Codable {
    case instagram = "INSTAGRAM"
    case twitter = "TWITTER"
    case facebook = "FACEBOOK"
    case other = "OTHER"
}

// MARK: - API Responses

struct PostcardsResponse: Codable {
    let postcards: [Postcard]
    let total: Int
    let page: Int
    let limit: Int
}

struct PostcardTemplatesResponse: Codable {
    let templates: [PostcardTemplate]
}

struct PostcardResponse: Codable {
    let postcard: Postcard
}

struct SharePostcardResponse: Codable {
    let shareUrl: String
    let imageUrl: String
}

// MARK: - Postcard Draft (Local)

struct PostcardDraft {
    var templateId: String?
    var template: PostcardTemplate?
    var quoteId: String?
    var quote: PostcardQuote?
    var customText: String?
    var backgroundColor: String?
    var textColor: String?
    var fontFamily: String?
    var isPublic: Bool = false

    var displayText: String {
        customText ?? quote?.text ?? ""
    }

    var bgColor: Color {
        if let hex = backgroundColor ?? template?.backgroundColor {
            return Color(hex: hex)
        }
        return .white
    }

    var txtColor: Color {
        if let hex = textColor ?? template?.fontColor {
            return Color(hex: hex)
        }
        return .black
    }

    func toCreateRequest() -> CreatePostcardRequest? {
        guard let templateId = templateId else { return nil }
        return CreatePostcardRequest(
            templateId: templateId,
            quoteId: quoteId,
            customText: customText,
            backgroundColor: backgroundColor,
            textColor: textColor,
            fontFamily: fontFamily,
            isPublic: isPublic
        )
    }
}

// MARK: - Font Options

enum PostcardFont: String, CaseIterable {
    case system = "System"
    case serif = "Georgia"
    case mono = "Menlo"
    case rounded = "SF Pro Rounded"

    var displayName: String {
        rawValue
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .system:
            return .system(size: size)
        case .serif:
            return .custom("Georgia", size: size)
        case .mono:
            return .custom("Menlo", size: size)
        case .rounded:
            return .system(size: size, design: .rounded)
        }
    }
}
