import SwiftUI
import WebKit

// MARK: - Page Turn Reader View

/// 使用 PageTurnEngine 的阅读器视图
/// 支持物理级翻页动画、声效和触觉反馈
struct PageTurnReaderView: View {
    let content: ChapterContent
    let theme: ReaderTheme
    let fontSize: FontSize
    let font: ReaderFont
    let settings: PageTurnSettings

    // Callbacks
    let onProgressUpdate: (Double) -> Void
    let onTextSelected: (String, String) -> Void
    let onTap: () -> Void
    var onPageChange: ((Int, Int) -> Void)? = nil
    var onReachChapterStart: (() -> Void)? = nil
    var onReachChapterEnd: (() -> Void)? = nil
    var onParagraphLongPress: ((Int, String) -> Void)? = nil

    @StateObject private var engine = PageTurnEngine()
    @State private var pages: [PageContent] = []
    @State private var isInitialized = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                theme.backgroundColor
                    .ignoresSafeArea()

                if isInitialized && !pages.isEmpty {
                    // Page turn container
                    PageTurnContainerView(engine: engine) { pageIndex in
                        pageView(for: pageIndex, size: geometry.size)
                    }

                    // Page indicator
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            pageIndicator
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                } else {
                    // Loading
                    ProgressView()
                }
            }
            .onAppear {
                setupEngine()
                paginateContent(size: geometry.size)
            }
            .onChange(of: content.id) { _, _ in
                paginateContent(size: geometry.size)
            }
            .onChange(of: fontSize) { _, _ in
                paginateContent(size: geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                paginateContent(size: newSize)
            }
        }
    }

    // MARK: - Page View

    @ViewBuilder
    private func pageView(for index: Int, size: CGSize) -> some View {
        if index >= 0 && index < pages.count {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Chapter title on first page
                    if index == 0 {
                        Text(content.title)
                            .font(.custom(font.rawValue, size: fontSize.textSize * 1.3))
                            .fontWeight(.semibold)
                            .foregroundColor(theme.textColor)
                            .padding(.bottom, 24)
                    }

                    // Page content
                    ForEach(pages[index].paragraphs) { paragraph in
                        Text(paragraph.text)
                            .font(.custom(font.rawValue, size: fontSize.textSize))
                            .foregroundColor(theme.textColor)
                            .lineSpacing(fontSize.textSize * (fontSize.lineHeight - 1))
                            .padding(.bottom, 16)
                            .textSelection(.disabled)
                            .onLongPressGesture(minimumDuration: 0.5) {
                                onParagraphLongPress?(paragraph.index, paragraph.text)
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 80)
            }
            .scrollDisabled(true) // Disable scroll, use page turn instead
            .background(theme.backgroundColor)
        } else {
            Color.clear
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        Text("\(engine.currentPage + 1) / \(engine.totalPages)")
            .font(.caption)
            .foregroundColor(theme.secondaryTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(theme.backgroundColor.opacity(0.9))
                    .shadow(color: .black.opacity(0.1), radius: 4)
            )
    }

    // MARK: - Setup

    private func setupEngine() {
        engine.settings = settings

        engine.onPageChange = { page in
            let total = engine.totalPages
            onPageChange?(page + 1, total)
            onProgressUpdate(total > 1 ? Double(page) / Double(total - 1) : 0)
        }

        engine.onReachStart = {
            onReachChapterStart?()
        }

        engine.onReachEnd = {
            onReachChapterEnd?()
        }
    }

    // MARK: - Pagination

    private func paginateContent(size: CGSize) {
        // 计算可用内容区域
        let contentWidth = size.width - 40 // 左右各 20pt padding
        let contentHeight = size.height - 140 // 上 60pt + 下 80pt padding

        // 估算每行字符数和每页行数
        let avgCharWidth = fontSize.textSize * 0.5
        let charsPerLine = Int(contentWidth / avgCharWidth)
        let lineHeight = fontSize.textSize * fontSize.lineHeight
        let linesPerPage = Int(contentHeight / lineHeight)

        // 将 HTML 内容转换为纯文本段落
        let paragraphTexts = extractParagraphs(from: content.htmlContent)

        // 创建带索引的段落
        let indexedParagraphs = paragraphTexts.enumerated().map { IndexedParagraph(index: $0.offset, text: $0.element) }

        // 分页
        var currentPage: [IndexedParagraph] = []
        var currentLineCount = 0
        var allPages: [PageContent] = []

        // 第一页需要留出标题空间
        let titleLines = 3
        var isFirstPage = true

        for paragraph in indexedParagraphs {
            let paragraphLines = estimateLines(for: paragraph.text, charsPerLine: charsPerLine)
            let availableLines = isFirstPage ? (linesPerPage - titleLines) : linesPerPage

            if currentLineCount + paragraphLines > availableLines && !currentPage.isEmpty {
                // 当前页满了，创建新页
                allPages.append(PageContent(paragraphs: currentPage))
                currentPage = []
                currentLineCount = 0
                isFirstPage = false
            }

            currentPage.append(paragraph)
            currentLineCount += paragraphLines + 1 // +1 for paragraph spacing
        }

        // 添加最后一页
        if !currentPage.isEmpty {
            allPages.append(PageContent(paragraphs: currentPage))
        }

        // 确保至少有一页
        if allPages.isEmpty {
            allPages.append(PageContent(paragraphs: [IndexedParagraph(index: 0, text: "...")]))
        }

        pages = allPages
        engine.totalPages = allPages.count
        engine.reset()
        isInitialized = true
    }

    private func extractParagraphs(from html: String) -> [String] {
        // 简单的 HTML 段落提取
        var text = html

        // 移除 style 和 script 标签
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)

        // 将块级标签转换为段落分隔符
        let blockTags = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", "<br>", "<br/>", "<br />"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n\n", options: .caseInsensitive)
        }

        // 移除所有 HTML 标签
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 解码 HTML 实体
        text = text.decodingHTMLEntities()

        // 分割成段落并清理
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return paragraphs
    }

    private func estimateLines(for text: String, charsPerLine: Int) -> Int {
        let charCount = text.count
        return max(1, Int(ceil(Double(charCount) / Double(charsPerLine))))
    }
}

// MARK: - Page Content Model

struct PageContent: Identifiable {
    let id = UUID()
    let paragraphs: [IndexedParagraph]
}

struct IndexedParagraph: Identifiable, Hashable {
    let id = UUID()
    let index: Int
    let text: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: IndexedParagraph, rhs: IndexedParagraph) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - String Extension for HTML Decoding

private extension String {
    func decodingHTMLEntities() -> String {
        var result = self

        let entities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&nbsp;": " ",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "\u{2026}",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}",
            "&rsquo;": "\u{2019}",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]

        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Handle numeric entities
        let numericPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: range)

            for match in matches.reversed() {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[codeRange]) {
                    if let scalar = Unicode.Scalar(code) {
                        let char = String(scalar)
                        if let fullRange = Range(match.range, in: result) {
                            result.replaceSubrange(fullRange, with: char)
                        }
                    }
                }
            }
        }

        return result
    }
}
