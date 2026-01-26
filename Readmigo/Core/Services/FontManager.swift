import SwiftUI
import CoreText
import UniformTypeIdentifiers

// MARK: - Font Category

/// Font category classification for organization and recommendation
enum FontCategory: String, Codable, CaseIterable {
    case serif = "serif"                    // Serif (formal, classic)
    case sansSerif = "sans_serif"           // Sans-serif (modern, clean)
    case monospace = "monospace"            // Monospace (code)
    case display = "display"                // Display (headlines)
    case handwriting = "handwriting"        // Handwriting
    case chinese = "chinese"                // Chinese-specific
    case dyslexia = "dyslexia"              // Dyslexia-friendly

    var displayName: String {
        switch self {
        case .serif: return "衬线体"
        case .sansSerif: return "无衬线"
        case .monospace: return "等宽字体"
        case .display: return "展示字体"
        case .handwriting: return "手写体"
        case .chinese: return "中文字体"
        case .dyslexia: return "阅读友好"
        }
    }

    var description: String {
        switch self {
        case .serif: return "适合长时间阅读，传统优雅"
        case .sansSerif: return "现代简洁，屏幕显示清晰"
        case .monospace: return "适合阅读代码和技术书籍"
        case .display: return "适合标题和强调内容"
        case .handwriting: return "亲切自然，适合休闲阅读"
        case .chinese: return "针对中文优化的字体"
        case .dyslexia: return "特别设计，帮助阅读障碍者"
        }
    }

    var icon: String {
        switch self {
        case .serif: return "textformat.abc"
        case .sansSerif: return "textformat"
        case .monospace: return "chevron.left.forwardslash.chevron.right"
        case .display: return "textformat.size.larger"
        case .handwriting: return "pencil.and.scribble"
        case .chinese: return "character"
        case .dyslexia: return "eye"
        }
    }
}

// MARK: - Font Source

/// Source type of the font
enum FontSource: String, Codable {
    case system = "system"          // iOS built-in fonts
    case bundled = "bundled"        // App bundled fonts
    case imported = "imported"      // User imported fonts
    case cloud = "cloud"            // Cloud fonts (on-demand download)
}

// MARK: - Reader Text Alignment

enum ReaderTextAlignment: String, Codable, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"
    case justified = "justified"

    var displayName: String {
        switch self {
        case .left: return "左对齐"
        case .center: return "居中"
        case .right: return "右对齐"
        case .justified: return "两端对齐"
        }
    }

    var cssValue: String {
        rawValue
    }
}

// MARK: - Font Weight

enum ReaderFontWeight: String, Codable, CaseIterable {
    case light = "light"
    case regular = "regular"
    case medium = "medium"
    case semibold = "semibold"
    case bold = "bold"

    var displayName: String {
        switch self {
        case .light: return "细体"
        case .regular: return "常规"
        case .medium: return "中等"
        case .semibold: return "半粗"
        case .bold: return "粗体"
        }
    }

    var cssValue: String {
        switch self {
        case .light: return "300"
        case .regular: return "400"
        case .medium: return "500"
        case .semibold: return "600"
        case .bold: return "700"
        }
    }

    var uiFontWeight: Font.Weight {
        switch self {
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

// MARK: - Font Settings

/// Comprehensive font settings for reader
struct FontSettings: Codable, Equatable {
    var bodyFont: String = "System"
    var headingFont: String = "System"
    var fontSize: CGFloat = 17
    var lineHeight: CGFloat = 1.5
    var letterSpacing: CGFloat = 0
    var wordSpacing: CGFloat = 0
    var paragraphSpacing: CGFloat = 12
    var textAlignment: ReaderTextAlignment = .justified
    var hyphenation: Bool = true
    var fontWeight: ReaderFontWeight = .regular

    // UserDefaults keys
    private enum Keys {
        static let bodyFont = "fontSettings.bodyFont"
        static let headingFont = "fontSettings.headingFont"
        static let fontSize = "fontSettings.fontSize"
        static let lineHeight = "fontSettings.lineHeight"
        static let letterSpacing = "fontSettings.letterSpacing"
        static let wordSpacing = "fontSettings.wordSpacing"
        static let paragraphSpacing = "fontSettings.paragraphSpacing"
        static let textAlignment = "fontSettings.textAlignment"
        static let hyphenation = "fontSettings.hyphenation"
        static let fontWeight = "fontSettings.fontWeight"
    }

    /// Load settings from UserDefaults
    static func load() -> FontSettings {
        let defaults = UserDefaults.standard
        var settings = FontSettings()

        if let bodyFont = defaults.string(forKey: Keys.bodyFont) {
            settings.bodyFont = bodyFont
        }
        if let headingFont = defaults.string(forKey: Keys.headingFont) {
            settings.headingFont = headingFont
        }
        if defaults.object(forKey: Keys.fontSize) != nil {
            settings.fontSize = defaults.double(forKey: Keys.fontSize)
        }
        if defaults.object(forKey: Keys.lineHeight) != nil {
            settings.lineHeight = defaults.double(forKey: Keys.lineHeight)
        }
        if defaults.object(forKey: Keys.letterSpacing) != nil {
            settings.letterSpacing = defaults.double(forKey: Keys.letterSpacing)
        }
        if defaults.object(forKey: Keys.wordSpacing) != nil {
            settings.wordSpacing = defaults.double(forKey: Keys.wordSpacing)
        }
        if defaults.object(forKey: Keys.paragraphSpacing) != nil {
            settings.paragraphSpacing = defaults.double(forKey: Keys.paragraphSpacing)
        }
        if let alignment = defaults.string(forKey: Keys.textAlignment),
           let textAlignment = ReaderTextAlignment(rawValue: alignment) {
            settings.textAlignment = textAlignment
        }
        if defaults.object(forKey: Keys.hyphenation) != nil {
            settings.hyphenation = defaults.bool(forKey: Keys.hyphenation)
        }
        if let weight = defaults.string(forKey: Keys.fontWeight),
           let fontWeight = ReaderFontWeight(rawValue: weight) {
            settings.fontWeight = fontWeight
        }

        return settings
    }

    /// Save settings to UserDefaults
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(bodyFont, forKey: Keys.bodyFont)
        defaults.set(headingFont, forKey: Keys.headingFont)
        defaults.set(fontSize, forKey: Keys.fontSize)
        defaults.set(lineHeight, forKey: Keys.lineHeight)
        defaults.set(letterSpacing, forKey: Keys.letterSpacing)
        defaults.set(wordSpacing, forKey: Keys.wordSpacing)
        defaults.set(paragraphSpacing, forKey: Keys.paragraphSpacing)
        defaults.set(textAlignment.rawValue, forKey: Keys.textAlignment)
        defaults.set(hyphenation, forKey: Keys.hyphenation)
        defaults.set(fontWeight.rawValue, forKey: Keys.fontWeight)
    }
}

// MARK: - Reader Font Family

/// Represents a font family available in the reader
struct ReaderFontFamily: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let displayName: String
    let category: FontCategory
    let source: FontSource
    let isSerif: Bool
    let sampleText: String
    let filePath: String?           // For imported fonts
    let downloadUrl: String?        // For cloud fonts
    let license: String?
    let features: [String]          // e.g., ["ligatures", "smallcaps"]

    var cssValue: String {
        switch source {
        case .system:
            return systemFontCSSValue
        case .bundled, .imported:
            return "'\(name)', \(fallbackStack)"
        case .cloud:
            return "'\(name)', \(fallbackStack)"
        }
    }

    private var systemFontCSSValue: String {
        switch name {
        case "System":
            return "-apple-system, BlinkMacSystemFont, sans-serif"
        case "System Serif":
            return "ui-serif, Georgia, serif"
        default:
            return "'\(name)', \(fallbackStack)"
        }
    }

    private var fallbackStack: String {
        if category == .chinese {
            return "'PingFang SC', 'STSong', serif"
        } else if isSerif {
            return "Georgia, 'Noto Serif SC', serif"
        } else {
            return "-apple-system, sans-serif"
        }
    }

    /// Create UIFont instance
    func uiFont(size: CGFloat, weight: ReaderFontWeight = .regular) -> UIFont {
        if source == .system && name == "System" {
            return UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight.toUIFontWeight())
        } else if source == .system && name == "System Serif" {
            if let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
                .withDesign(.serif) {
                return UIFont(descriptor: descriptor, size: size)
            }
        }
        return UIFont(name: name, size: size) ?? UIFont.systemFont(ofSize: size)
    }

    /// Create SwiftUI Font instance
    func swiftUIFont(size: CGFloat) -> Font {
        if source == .system && name == "System" {
            return .system(size: size)
        } else if source == .system && name == "System Serif" {
            return .system(size: size, design: .serif)
        }
        return .custom(name, size: size)
    }
}

// MARK: - Font Recommendation

/// Font recommendation with reasoning
struct FontRecommendation: Identifiable {
    let id = UUID()
    let font: ReaderFontFamily
    let score: Double           // 0-100 recommendation score
    let reasons: [String]       // Why this font is recommended
}

// MARK: - Book Category for Recommendations

/// Book category used for font recommendations
enum BookCategory: String {
    case fiction
    case technical
    case academic
    case casual
    case poetry
    case children

    static func from(genres: [String]) -> BookCategory {
        let genresLower = genres.map { $0.lowercased() }

        if genresLower.contains(where: { $0.contains("technical") || $0.contains("programming") || $0.contains("science") }) {
            return .technical
        }
        if genresLower.contains(where: { $0.contains("academic") || $0.contains("research") || $0.contains("philosophy") }) {
            return .academic
        }
        if genresLower.contains(where: { $0.contains("poetry") || $0.contains("verse") }) {
            return .poetry
        }
        if genresLower.contains(where: { $0.contains("children") || $0.contains("kids") || $0.contains("young") }) {
            return .children
        }
        if genresLower.contains(where: { $0.contains("casual") || $0.contains("humor") || $0.contains("comedy") }) {
            return .casual
        }
        return .fiction
    }
}

// MARK: - Font Import Error

enum FontImportError: LocalizedError {
    case invalidFontFile
    case fontRegistrationFailed
    case fontAlreadyExists
    case fileAccessDenied
    case unsupportedFormat
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .invalidFontFile:
            return "无效的字体文件"
        case .fontRegistrationFailed:
            return "字体注册失败"
        case .fontAlreadyExists:
            return "字体已存在"
        case .fileAccessDenied:
            return "文件访问被拒绝"
        case .unsupportedFormat:
            return "不支持的字体格式"
        case .copyFailed:
            return "复制字体文件失败"
        }
    }
}

// MARK: - Font Manager

/// Central manager for all font operations
@MainActor
class FontManager: ObservableObject {
    static let shared = FontManager()

    // MARK: - Published Properties

    @Published private(set) var systemFonts: [ReaderFontFamily] = []
    @Published private(set) var bundledFonts: [ReaderFontFamily] = []
    @Published private(set) var importedFonts: [ReaderFontFamily] = []
    @Published private(set) var cloudFonts: [ReaderFontFamily] = []
    @Published var fontSettings: FontSettings {
        didSet {
            fontSettings.save()
        }
    }

    /// All available fonts combined
    var allFonts: [ReaderFontFamily] {
        systemFonts + bundledFonts + importedFonts + cloudFonts
    }

    /// Fonts grouped by category
    var fontsByCategory: [FontCategory: [ReaderFontFamily]] {
        Dictionary(grouping: allFonts, by: { $0.category })
    }

    // MARK: - Private Properties

    private let importedFontsDirectory: URL
    private let importedFontsKey = "importedFonts"

    // MARK: - Initialization

    private init() {
        // Setup imported fonts directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        importedFontsDirectory = documentsPath.appendingPathComponent("Fonts", isDirectory: true)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: importedFontsDirectory, withIntermediateDirectories: true)

        // Load font settings
        fontSettings = FontSettings.load()

        // Initialize font sources
        loadSystemFonts()
        loadBundledFonts()
        loadImportedFonts()
        loadCloudFonts()
    }

    // MARK: - Font Loading

    /// Load system fonts
    private func loadSystemFonts() {
        systemFonts = [
            ReaderFontFamily(
                id: "system",
                name: "System",
                displayName: "系统字体",
                category: .sansSerif,
                source: .system,
                isSerif: false,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Apple",
                features: []
            ),
            ReaderFontFamily(
                id: "system-serif",
                name: "System Serif",
                displayName: "系统衬线",
                category: .serif,
                source: .system,
                isSerif: true,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Apple",
                features: []
            ),
            ReaderFontFamily(
                id: "georgia",
                name: "Georgia",
                displayName: "Georgia",
                category: .serif,
                source: .system,
                isSerif: true,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Microsoft",
                features: ["ligatures"]
            ),
            ReaderFontFamily(
                id: "palatino",
                name: "Palatino",
                displayName: "Palatino",
                category: .serif,
                source: .system,
                isSerif: true,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Linotype",
                features: ["ligatures", "smallcaps"]
            ),
            ReaderFontFamily(
                id: "times",
                name: "Times New Roman",
                displayName: "Times",
                category: .serif,
                source: .system,
                isSerif: true,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Monotype",
                features: []
            ),
            ReaderFontFamily(
                id: "baskerville",
                name: "Baskerville",
                displayName: "Baskerville",
                category: .serif,
                source: .system,
                isSerif: true,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Apple",
                features: ["ligatures"]
            ),
            ReaderFontFamily(
                id: "helvetica",
                name: "Helvetica Neue",
                displayName: "Helvetica",
                category: .sansSerif,
                source: .system,
                isSerif: false,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Linotype",
                features: []
            ),
            ReaderFontFamily(
                id: "avenir",
                name: "Avenir",
                displayName: "Avenir",
                category: .sansSerif,
                source: .system,
                isSerif: false,
                sampleText: "The quick brown fox",
                filePath: nil,
                downloadUrl: nil,
                license: "Linotype",
                features: []
            ),
            // Chinese fonts
            ReaderFontFamily(
                id: "pingfang",
                name: "PingFang SC",
                displayName: "苹方",
                category: .chinese,
                source: .system,
                isSerif: false,
                sampleText: "天地玄黄，宇宙洪荒",
                filePath: nil,
                downloadUrl: nil,
                license: "Apple",
                features: []
            ),
            ReaderFontFamily(
                id: "songti",
                name: "Songti SC",
                displayName: "宋体",
                category: .chinese,
                source: .system,
                isSerif: true,
                sampleText: "天地玄黄，宇宙洪荒",
                filePath: nil,
                downloadUrl: nil,
                license: "Apple",
                features: []
            ),
            ReaderFontFamily(
                id: "kaiti",
                name: "Kaiti SC",
                displayName: "楷体",
                category: .chinese,
                source: .system,
                isSerif: true,
                sampleText: "天地玄黄，宇宙洪荒",
                filePath: nil,
                downloadUrl: nil,
                license: "Apple",
                features: []
            )
        ]
    }

    /// Load bundled fonts (fonts included with the app)
    private func loadBundledFonts() {
        // Bundled fonts would be loaded from app bundle
        // These are premium open-source fonts we ship with the app
        bundledFonts = [
            // Note: These fonts need to be added to the app bundle and Info.plist
            // Leaving as placeholders for now
        ]

        // TODO: Add bundled fonts when font files are added to the project:
        // - Literata (Google's open-source reading font)
        // - Crimson Pro (elegant serif)
        // - Merriweather (screen-optimized serif)
        // - Source Serif Pro (Adobe open-source serif)
        // - OpenDyslexic (dyslexia-friendly)
        // - Atkinson Hyperlegible (high readability)
    }

    /// Load imported fonts from disk
    private func loadImportedFonts() {
        guard let savedData = UserDefaults.standard.data(forKey: importedFontsKey),
              let fonts = try? JSONDecoder().decode([ReaderFontFamily].self, from: savedData) else {
            importedFonts = []
            return
        }

        // Verify files exist and register fonts
        importedFonts = fonts.filter { font in
            guard let filePath = font.filePath else { return false }
            let fileURL = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // Register font with system
                registerFont(at: fileURL)
                return true
            }
            return false
        }
    }

    /// Load cloud fonts catalog
    private func loadCloudFonts() {
        // Cloud fonts would be loaded from API
        // For now, using placeholder data
        cloudFonts = []

        // TODO: Fetch from API
        // GET /api/fonts/catalog
    }

    // MARK: - Font Import

    /// Import font from URL
    func importFont(from url: URL) async throws -> ReaderFontFamily {
        // 1. Validate font file
        guard url.startAccessingSecurityScopedResource() else {
            throw FontImportError.fileAccessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let fileExtension = url.pathExtension.lowercased()
        guard ["ttf", "otf", "ttc"].contains(fileExtension) else {
            throw FontImportError.unsupportedFormat
        }

        // 2. Parse font information
        guard let fontDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              let fontDescriptor = fontDescriptors.first else {
            throw FontImportError.invalidFontFile
        }

        let fontName = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontNameAttribute) as? String ?? url.deletingPathExtension().lastPathComponent
        let familyName = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontFamilyNameAttribute) as? String ?? fontName
        let displayName = CTFontDescriptorCopyAttribute(fontDescriptor, kCTFontDisplayNameAttribute) as? String ?? familyName

        // 3. Check if font already exists
        let fontId = fontName.lowercased().replacingOccurrences(of: " ", with: "-")
        if allFonts.contains(where: { $0.id == fontId }) {
            throw FontImportError.fontAlreadyExists
        }

        // 4. Copy to app's font directory
        let destinationURL = importedFontsDirectory.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }

        do {
            try FileManager.default.copyItem(at: url, to: destinationURL)
        } catch {
            throw FontImportError.copyFailed
        }

        // 5. Register font with system
        guard registerFont(at: destinationURL) else {
            try? FileManager.default.removeItem(at: destinationURL)
            throw FontImportError.fontRegistrationFailed
        }

        // 6. Create font model
        let fontFamily = ReaderFontFamily(
            id: fontId,
            name: fontName,
            displayName: displayName,
            category: detectCategory(from: fontDescriptor),
            source: .imported,
            isSerif: detectSerif(from: fontDescriptor),
            sampleText: "The quick brown fox",
            filePath: destinationURL.path,
            downloadUrl: nil,
            license: "User Imported",
            features: detectFeatures(from: fontDescriptor)
        )

        // 7. Save to imported fonts
        importedFonts.append(fontFamily)
        saveImportedFonts()

        return fontFamily
    }

    /// Delete imported font
    func deleteImportedFont(_ font: ReaderFontFamily) throws {
        guard font.source == .imported else { return }

        // Unregister font
        if let filePath = font.filePath {
            let url = URL(fileURLWithPath: filePath)
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)

            // Delete file
            try? FileManager.default.removeItem(at: url)
        }

        // Remove from list
        importedFonts.removeAll { $0.id == font.id }
        saveImportedFonts()

        // Reset to system font if deleted font was active
        if fontSettings.bodyFont == font.name {
            fontSettings.bodyFont = "System"
        }
        if fontSettings.headingFont == font.name {
            fontSettings.headingFont = "System"
        }
    }

    // MARK: - Font Registration

    @discardableResult
    private func registerFont(at url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if !success {
            if let error = error?.takeRetainedValue() {
                print("Font registration error: \(error)")
            }
        }
        return success
    }

    private func saveImportedFonts() {
        if let data = try? JSONEncoder().encode(importedFonts) {
            UserDefaults.standard.set(data, forKey: importedFontsKey)
        }
    }

    // MARK: - Font Detection Helpers

    private func detectCategory(from descriptor: CTFontDescriptor) -> FontCategory {
        let traits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? [String: Any]
        let symbolicTraits = traits?[kCTFontSymbolicTrait as String] as? UInt32 ?? 0

        if symbolicTraits & CTFontSymbolicTraits.traitMonoSpace.rawValue != 0 {
            return .monospace
        }

        // Check font name for category hints
        let name = (CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? "").lowercased()

        // Known serif font families
        let serifFonts = ["georgia", "times", "palatino", "baskerville", "didot", "hoefler", "cochin", "charter"]
        for serifFont in serifFonts {
            if name.contains(serifFont) {
                return .serif
            }
        }

        if name.contains("serif") && !name.contains("sans") {
            return .serif
        }
        if name.contains("mono") || name.contains("code") || name.contains("courier") || name.contains("menlo") {
            return .monospace
        }
        if name.contains("script") || name.contains("hand") || name.contains("cursive") {
            return .handwriting
        }
        if name.contains("display") {
            return .display
        }
        if name.contains("dyslexic") || name.contains("opendyslexic") {
            return .dyslexia
        }

        return .sansSerif
    }

    private func detectSerif(from descriptor: CTFontDescriptor) -> Bool {
        // Check font name for serif indicators
        let name = (CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? "").lowercased()

        // Known serif font families
        let serifFonts = ["georgia", "times", "palatino", "baskerville", "didot", "hoefler", "cochin", "charter"]
        for serifFont in serifFonts {
            if name.contains(serifFont) {
                return true
            }
        }

        if name.contains("serif") && !name.contains("sans") {
            return true
        }

        return false
    }

    private func detectFeatures(from descriptor: CTFontDescriptor) -> [String] {
        var features: [String] = []

        if let fontFeatures = CTFontDescriptorCopyAttribute(descriptor, kCTFontFeaturesAttribute) as? [[String: Any]] {
            for feature in fontFeatures {
                if let featureName = feature[kCTFontFeatureTypeNameKey as String] as? String {
                    features.append(featureName.lowercased())
                }
            }
        }

        return features
    }

    // MARK: - Smart Font Recommendations

    /// Recommend fonts for a book based on its genre and user preferences
    func recommendFonts(for book: Book, userPreferences: FontSettings) -> [FontRecommendation] {
        let bookCategory = BookCategory.from(genres: book.genres ?? [])
        var recommendations: [FontRecommendation] = []

        for font in allFonts {
            var score: Double = 50.0
            var reasons: [String] = []

            // Category matching
            switch bookCategory {
            case .fiction:
                if font.category == .serif {
                    score += 20
                    reasons.append("衬线体适合小说阅读")
                }
                if font.id == "georgia" || font.id == "palatino" {
                    score += 10
                    reasons.append("经典阅读字体")
                }

            case .technical:
                if font.category == .monospace {
                    score += 25
                    reasons.append("等宽字体适合代码阅读")
                }
                if font.category == .sansSerif {
                    score += 15
                    reasons.append("无衬线字体清晰易读")
                }

            case .academic:
                if font.category == .serif {
                    score += 20
                    reasons.append("衬线体适合学术阅读")
                }
                if font.id == "times" || font.id == "palatino" {
                    score += 10
                    reasons.append("学术论文标准字体")
                }

            case .casual:
                if font.category == .sansSerif {
                    score += 15
                    reasons.append("轻松现代的阅读体验")
                }
                if font.category == .dyslexia {
                    score += 10
                    reasons.append("高可读性字体")
                }

            case .poetry:
                if font.category == .serif {
                    score += 15
                    reasons.append("优雅的排版效果")
                }
                if font.category == .handwriting {
                    score += 10
                    reasons.append("富有诗意的手写风格")
                }

            case .children:
                if font.category == .sansSerif {
                    score += 15
                    reasons.append("清晰简洁易于阅读")
                }
                if font.category == .dyslexia {
                    score += 20
                    reasons.append("儿童友好型字体")
                }
            }

            // User preference matching
            if userPreferences.fontSize > 20 {
                // Large font users might prefer high-readability fonts
                if font.category == .dyslexia {
                    score += 15
                    reasons.append("护眼大字体推荐")
                }
            }

            // Chinese book detection
            let genres: [String] = book.genres ?? []
            let isChinese = genres.contains(where: { $0.lowercased().contains("chinese") })
            if isChinese && font.category == .chinese {
                score += 25
                reasons.append("中文优化字体")
            }

            // Only include fonts with meaningful scores
            if score > 50 {
                recommendations.append(FontRecommendation(
                    font: font,
                    score: min(score, 100),
                    reasons: reasons
                ))
            }
        }

        // Sort by score descending
        return recommendations.sorted { $0.score > $1.score }
    }

    // MARK: - Font Lookup

    /// Get font by ID
    func font(byId id: String) -> ReaderFontFamily? {
        allFonts.first { $0.id == id }
    }

    /// Get font by name
    func font(byName name: String) -> ReaderFontFamily? {
        allFonts.first { $0.name == name }
    }

    /// Get current body font
    var currentBodyFont: ReaderFontFamily? {
        font(byName: fontSettings.bodyFont)
    }

    /// Get current heading font
    var currentHeadingFont: ReaderFontFamily? {
        font(byName: fontSettings.headingFont)
    }
}

// MARK: - Font.Weight Extension

extension Font.Weight {
    func toUIFontWeight() -> UIFont.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
}
