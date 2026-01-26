import SwiftUI
import Combine

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable, Codable {
    case system  // 跟随系统
    case light   // 始终浅色
    case dark    // 始终深色

    var displayName: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

// MARK: - Reader Font Family
enum ReaderFont: String, CaseIterable, Codable {
    // System fonts
    case system = "System"
    case systemSerif = "System Serif"

    // Classic serif fonts
    case georgia = "Georgia"
    case palatino = "Palatino"
    case times = "Times New Roman"
    case baskerville = "Baskerville"

    // Sans-serif fonts
    case helvetica = "Helvetica Neue"
    case avenir = "Avenir"

    // Chinese fonts
    case pingfang = "PingFang SC"
    case songti = "Songti SC"
    case kaiti = "Kaiti SC"

    var displayName: String {
        switch self {
        case .system: return "系统字体"
        case .systemSerif: return "系统衬线"
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .times: return "Times"
        case .baskerville: return "Baskerville"
        case .helvetica: return "Helvetica"
        case .avenir: return "Avenir"
        case .pingfang: return "苹方"
        case .songti: return "宋体"
        case .kaiti: return "楷体"
        }
    }

    var cssValue: String {
        switch self {
        case .system:
            return "-apple-system, BlinkMacSystemFont, sans-serif"
        case .systemSerif:
            return "ui-serif, Georgia, serif"
        case .georgia:
            return "'Georgia', 'Noto Serif SC', serif"
        case .palatino:
            return "'Palatino Linotype', 'Book Antiqua', Palatino, serif"
        case .times:
            return "'Times New Roman', Times, serif"
        case .baskerville:
            return "Baskerville, 'Baskerville Old Face', serif"
        case .helvetica:
            return "'Helvetica Neue', Helvetica, Arial, sans-serif"
        case .avenir:
            return "Avenir, 'Avenir Next', sans-serif"
        case .pingfang:
            return "'PingFang SC', -apple-system, sans-serif"
        case .songti:
            return "'Songti SC', 'STSong', serif"
        case .kaiti:
            return "'Kaiti SC', 'STKaiti', serif"
        }
    }

    var isSerif: Bool {
        switch self {
        case .system, .helvetica, .avenir, .pingfang:
            return false
        default:
            return true
        }
    }

    var sampleText: String {
        switch self {
        case .pingfang, .songti, .kaiti:
            return "天地玄黄，宇宙洪荒"
        default:
            return "The quick brown fox"
        }
    }
}

// MARK: - Reading Mode (Legacy - for backward compatibility)
/// Note: Use PageTurnMode for advanced page turning features
enum ReadingMode: String, CaseIterable, Codable {
    case curlPage = "curl"           // 仿真翻页
    case horizontalSlide = "slide"   // 左右滑动
    case verticalScroll = "scroll"   // 上下滚动

    var displayName: String {
        switch self {
        case .curlPage: return "仿真翻页"
        case .horizontalSlide: return "左右滑动"
        case .verticalScroll: return "上下滚动"
        }
    }

    var icon: String {
        switch self {
        case .curlPage: return "book.pages"
        case .horizontalSlide: return "arrow.left.arrow.right"
        case .verticalScroll: return "scroll"
        }
    }

    /// Whether this mode displays content in pages (vs continuous scroll)
    var isPaged: Bool {
        self != .verticalScroll
    }

    /// Whether this mode supports auto page turning
    var supportsAutoPage: Bool {
        self != .verticalScroll
    }

    /// Convert to new PageTurnMode
    var toPageTurnMode: PageTurnMode {
        switch self {
        case .curlPage: return .pageCurl
        case .horizontalSlide: return .slide
        case .verticalScroll: return .scroll
        }
    }

    /// Create from PageTurnMode
    init(from pageTurnMode: PageTurnMode) {
        switch pageTurnMode {
        case .scroll: self = .verticalScroll
        case .slide: self = .horizontalSlide
        case .pageCurl, .realistic, .flip, .cover, .accordion, .cube:
            self = .curlPage
        case .fade, .none:
            self = .horizontalSlide
        }
    }
}

// MARK: - Auto Page Interval
enum AutoPageInterval: Double, CaseIterable, Codable {
    case fast = 15      // 15 seconds
    case medium = 30    // 30 seconds
    case slow = 60      // 60 seconds

    var displayName: String {
        switch self {
        case .fast: return "15秒"
        case .medium: return "30秒"
        case .slow: return "60秒"
        }
    }

    var seconds: TimeInterval {
        rawValue
    }
}

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Font Manager Integration
    private let fontManager = FontManager.shared
    private var cancellables = Set<AnyCancellable>()

    @Published var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: "appearanceMode")
        }
    }

    /// Legacy computed property for backwards compatibility
    var isDarkMode: Bool {
        get { appearanceMode == .dark }
        set { appearanceMode = newValue ? .dark : .light }
    }

    @Published var fontSize: FontSize {
        didSet {
            UserDefaults.standard.set(fontSize.rawValue, forKey: "fontSize")
            // Sync with FontManager
            fontManager.fontSettings.fontSize = fontSize.textSize
        }
    }

    @Published var readerTheme: ReaderTheme {
        didSet {
            UserDefaults.standard.set(readerTheme.rawValue, forKey: "readerTheme")
        }
    }

    @Published var lineSpacing: LineSpacing {
        didSet {
            UserDefaults.standard.set(lineSpacing.rawValue, forKey: "lineSpacing")
        }
    }

    @Published var autoBrightness: Bool {
        didSet {
            UserDefaults.standard.set(autoBrightness, forKey: "autoBrightness")
        }
    }

    @Published var brightness: Double {
        didSet {
            UserDefaults.standard.set(brightness, forKey: "brightness")
        }
    }

    @Published var readingMode: ReadingMode {
        didSet {
            UserDefaults.standard.set(readingMode.rawValue, forKey: "readingMode")
        }
    }

    @Published var readerFont: ReaderFont {
        didSet {
            UserDefaults.standard.set(readerFont.rawValue, forKey: "readerFont")
            // Sync with FontManager
            fontManager.fontSettings.bodyFont = readerFont.rawValue
        }
    }

    @Published var autoPageEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoPageEnabled, forKey: "autoPageEnabled")
        }
    }

    @Published var autoPageInterval: AutoPageInterval {
        didSet {
            UserDefaults.standard.set(autoPageInterval.rawValue, forKey: "autoPageInterval")
        }
    }

    // MARK: - Advanced Page Turn Settings

    /// Advanced page turn settings (physics, sound, haptic)
    /// Uses PageTurnSettingsManager.shared as the source of truth
    var pageTurnSettings: PageTurnSettings {
        get { pageTurnSettingsManager.settings }
        set { pageTurnSettingsManager.settings = newValue }
    }

    private let pageTurnSettingsManager = PageTurnSettingsManager.shared

    // MARK: - Advanced Typography Settings

    @Published var letterSpacing: CGFloat {
        didSet {
            UserDefaults.standard.set(letterSpacing, forKey: "letterSpacing")
            fontManager.fontSettings.letterSpacing = letterSpacing
        }
    }

    @Published var wordSpacing: CGFloat {
        didSet {
            UserDefaults.standard.set(wordSpacing, forKey: "wordSpacing")
            fontManager.fontSettings.wordSpacing = wordSpacing
        }
    }

    @Published var paragraphSpacing: CGFloat {
        didSet {
            UserDefaults.standard.set(paragraphSpacing, forKey: "paragraphSpacing")
            fontManager.fontSettings.paragraphSpacing = paragraphSpacing
        }
    }

    @Published var textAlignment: ReaderTextAlignment {
        didSet {
            UserDefaults.standard.set(textAlignment.rawValue, forKey: "textAlignment")
            fontManager.fontSettings.textAlignment = textAlignment
        }
    }

    @Published var hyphenation: Bool {
        didSet {
            UserDefaults.standard.set(hyphenation, forKey: "hyphenation")
            fontManager.fontSettings.hyphenation = hyphenation
        }
    }

    @Published var fontWeight: ReaderFontWeight {
        didSet {
            UserDefaults.standard.set(fontWeight.rawValue, forKey: "fontWeight")
            fontManager.fontSettings.fontWeight = fontWeight
        }
    }

    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil  // SwiftUI will follow system setting
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// Current font settings from FontManager
    var currentFontSettings: FontSettings {
        fontManager.fontSettings
    }

    /// All available fonts
    var availableFonts: [ReaderFontFamily] {
        fontManager.allFonts
    }

    /// Fonts grouped by category
    var fontsByCategory: [FontCategory: [ReaderFontFamily]] {
        fontManager.fontsByCategory
    }

    func setFontSize(_ size: Double) {
        // Map numeric size to FontSize enum
        if size < 19 {
            fontSize = .medium
        } else if size < 22 {
            fontSize = .large
        } else if size < 26 {
            fontSize = .extraLarge
        } else {
            fontSize = .huge
        }
    }

    /// Import a font from URL
    func importFont(from url: URL) async throws -> ReaderFontFamily {
        try await fontManager.importFont(from: url)
    }

    /// Delete an imported font
    func deleteImportedFont(_ font: ReaderFontFamily) throws {
        try fontManager.deleteImportedFont(font)
    }

    /// Get font recommendations for a book
    func recommendFonts(for book: Book) -> [FontRecommendation] {
        fontManager.recommendFonts(for: book, userPreferences: fontManager.fontSettings)
    }

    private init() {
        // Load advanced typography settings
        self.letterSpacing = UserDefaults.standard.double(forKey: "letterSpacing")
        self.wordSpacing = UserDefaults.standard.double(forKey: "wordSpacing")
        let savedParagraphSpacing = UserDefaults.standard.double(forKey: "paragraphSpacing")
        self.paragraphSpacing = savedParagraphSpacing == 0 ? 12 : savedParagraphSpacing
        self.textAlignment = ReaderTextAlignment(rawValue: UserDefaults.standard.string(forKey: "textAlignment") ?? "") ?? .justified
        self.hyphenation = UserDefaults.standard.object(forKey: "hyphenation") == nil ? true : UserDefaults.standard.bool(forKey: "hyphenation")
        self.fontWeight = ReaderFontWeight(rawValue: UserDefaults.standard.string(forKey: "fontWeight") ?? "") ?? .regular

        // Migrate from old isDarkMode to new appearanceMode
        let resolvedMode: AppearanceMode
        if let savedMode = UserDefaults.standard.string(forKey: "appearanceMode"),
           let mode = AppearanceMode(rawValue: savedMode) {
            resolvedMode = mode
        } else if UserDefaults.standard.object(forKey: "isDarkMode") != nil {
            // Migrate from legacy isDarkMode setting
            let wasDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
            resolvedMode = wasDarkMode ? .dark : .light
            UserDefaults.standard.removeObject(forKey: "isDarkMode")
            UserDefaults.standard.set(resolvedMode.rawValue, forKey: "appearanceMode")
        } else {
            // Default to system for new users
            resolvedMode = .system
        }
        self.appearanceMode = resolvedMode

        self.fontSize = FontSize(rawValue: UserDefaults.standard.string(forKey: "fontSize") ?? "") ?? .large
        self.readerTheme = ReaderTheme(rawValue: UserDefaults.standard.string(forKey: "readerTheme") ?? "") ?? .light
        self.lineSpacing = LineSpacing(rawValue: UserDefaults.standard.string(forKey: "lineSpacing") ?? "") ?? .normal
        self.autoBrightness = UserDefaults.standard.bool(forKey: "autoBrightness")
        self.readingMode = ReadingMode(rawValue: UserDefaults.standard.string(forKey: "readingMode") ?? "") ?? .horizontalSlide
        self.readerFont = ReaderFont(rawValue: UserDefaults.standard.string(forKey: "readerFont") ?? "") ?? .georgia
        self.autoPageEnabled = UserDefaults.standard.bool(forKey: "autoPageEnabled")
        self.autoPageInterval = AutoPageInterval(rawValue: UserDefaults.standard.double(forKey: "autoPageInterval")) ?? .slow

        // Initialize brightness last and handle default
        let savedBrightness = UserDefaults.standard.double(forKey: "brightness")
        self.brightness = savedBrightness == 0 ? 0.5 : savedBrightness

        // Sync initial values to FontManager
        fontManager.fontSettings.fontSize = fontSize.textSize
        fontManager.fontSettings.bodyFont = readerFont.rawValue
        fontManager.fontSettings.letterSpacing = letterSpacing
        fontManager.fontSettings.wordSpacing = wordSpacing
        fontManager.fontSettings.paragraphSpacing = paragraphSpacing
        fontManager.fontSettings.textAlignment = textAlignment
        fontManager.fontSettings.hyphenation = hyphenation
        fontManager.fontSettings.fontWeight = fontWeight
    }
}

enum FontSize: String, CaseIterable {
    case medium
    case large
    case extraLarge
    case huge

    var displayName: String {
        switch self {
        case .medium: return "较小"
        case .large: return "标准"
        case .extraLarge: return "较大"
        case .huge: return "更大"
        }
    }

    var textSize: CGFloat {
        switch self {
        case .medium: return 17
        case .large: return 20
        case .extraLarge: return 24
        case .huge: return 28
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .medium: return 1.5
        case .large: return 1.6
        case .extraLarge: return 1.7
        case .huge: return 1.8
        }
    }

    // Compatibility alias
    var size: CGFloat { textSize }
}

enum LineSpacing: String, CaseIterable {
    case compact
    case normal
    case relaxed
    case extraRelaxed

    var value: CGFloat {
        switch self {
        case .compact: return 4
        case .normal: return 8
        case .relaxed: return 12
        case .extraRelaxed: return 16
        }
    }
}

enum ReaderTheme: String, CaseIterable {
    case light
    case sepia
    case dark

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .sepia: return "Sepia"
        case .dark: return "Dark"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: return .white
        case .sepia: return Color(red: 0.98, green: 0.95, blue: 0.89)
        case .dark: return Color(red: 0.12, green: 0.12, blue: 0.12)
        }
    }

    var textColor: Color {
        switch self {
        case .light: return .black
        case .sepia: return Color(red: 0.3, green: 0.2, blue: 0.1)
        case .dark: return Color(white: 0.85)
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: return .gray
        case .sepia: return Color(red: 0.5, green: 0.4, blue: 0.3)
        case .dark: return Color(white: 0.6)
        }
    }

    var highlightColor: Color {
        switch self {
        case .light: return .yellow.opacity(0.3)
        case .sepia: return .orange.opacity(0.3)
        case .dark: return .blue.opacity(0.3)
        }
    }

    var linkColor: Color {
        switch self {
        case .light: return Color(hex: "007AFF")  // iOS system blue
        case .sepia: return Color(hex: "0066CC")  // Darker blue for sepia
        case .dark: return Color(hex: "64B5F6")   // Lighter blue for dark
        }
    }

    /// Returns hex string for CSS usage
    var linkColorHex: String {
        switch self {
        case .light: return "#007AFF"
        case .sepia: return "#0066CC"
        case .dark: return "#64B5F6"
        }
    }
}
