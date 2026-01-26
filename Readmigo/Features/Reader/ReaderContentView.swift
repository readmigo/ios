import SwiftUI
import WebKit

/// Information about an image in the chapter content
struct ImageInfo: Identifiable {
    let id: String
    let src: String
    let alt: String?
    let caption: String?
    let index: Int
}

struct ReaderContentView: UIViewRepresentable {
    let content: ChapterContent
    let theme: ReaderTheme
    let fontSize: FontSize
    let font: ReaderFont
    let readingMode: ReadingMode
    let autoPageEnabled: Bool
    let autoPageInterval: AutoPageInterval
    let onProgressUpdate: (Double) -> Void
    let onTextSelected: (String, String) -> Void
    let onTap: () -> Void
    var onPageChange: ((Int, Int) -> Void)? = nil
    var onReachChapterStart: (() -> Void)? = nil
    var onReachChapterEnd: (() -> Void)? = nil
    var onAutoPageEnd: (() -> Void)? = nil
    var onContentReady: (() -> Void)? = nil

    // Highlight rendering
    var highlights: [Bookmark] = []
    var onHighlightTap: ((Bookmark) -> Void)? = nil

    // Image viewer
    var onImageTap: ((String, String?, [ImageInfo]) -> Void)? = nil

    // Advanced typography settings
    var lineSpacing: LineSpacing = .normal
    var letterSpacing: CGFloat = 0
    var wordSpacing: CGFloat = 0
    var paragraphSpacing: CGFloat = 12
    var textAlignment: ReaderTextAlignment = .justified
    var hyphenation: Bool = true
    var fontWeight: ReaderFontWeight = .regular

    // Cross-chapter navigation: start from last page when navigating backwards
    var startFromLastPage: Bool = false

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(context.coordinator, name: "textSelection")
        configuration.userContentController.add(context.coordinator, name: "tap")
        configuration.userContentController.add(context.coordinator, name: "scroll")
        configuration.userContentController.add(context.coordinator, name: "pageChange")
        configuration.userContentController.add(context.coordinator, name: "navigation")
        configuration.userContentController.add(context.coordinator, name: "highlightTap")
        configuration.userContentController.add(context.coordinator, name: "imageTap")
        configuration.userContentController.add(context.coordinator, name: "readerLog")
        configuration.userContentController.add(context.coordinator, name: "contentReady")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        webView.scrollView.backgroundColor = UIColor.clear
        webView.scrollView.delegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView

        // Disable zoom
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0

        // Disable bounce effect (rubber band effect)
        webView.scrollView.bounces = false

        // Disable scrolling for paged modes
        webView.scrollView.isScrollEnabled = !readingMode.isPaged

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Update callbacks (these don't trigger re-render)
        context.coordinator.onProgressUpdate = onProgressUpdate
        context.coordinator.onTextSelected = onTextSelected
        context.coordinator.onTap = onTap
        context.coordinator.onPageChange = onPageChange
        context.coordinator.onReachChapterStart = onReachChapterStart
        context.coordinator.onReachChapterEnd = onReachChapterEnd
        context.coordinator.onAutoPageEnd = onAutoPageEnd
        context.coordinator.onHighlightTap = onHighlightTap
        context.coordinator.onImageTap = onImageTap
        context.coordinator.onContentReady = onContentReady
        context.coordinator.highlights = highlights

        // Update scroll enabled based on reading mode
        webView.scrollView.isScrollEnabled = !readingMode.isPaged

        // Only reload HTML if content actually changed (prevent infinite loop)
        // Note: startFromLastPage is intentionally NOT in contentKey - it's a one-time navigation flag
        let contentKey = "\(content.id)_\(readingMode.rawValue)_\(fontSize.rawValue)_\(font.rawValue)_\(theme.rawValue)_\(lineSpacing.rawValue)"
        if context.coordinator.lastContentKey != contentKey {
            context.coordinator.lastContentKey = contentKey
            let html = generateHTML()
            webView.loadHTMLString(html, baseURL: URL(string: "https://cdn.readmigo.app/"))

            // Handle auto page after content loads
            if autoPageEnabled && readingMode.supportsAutoPage {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    webView.evaluateJavaScript("startAutoPage(\(Int(self.autoPageInterval.seconds * 1000)))")
                }
            }
        } else {
            // Only update auto page settings without reloading
            if autoPageEnabled && readingMode.supportsAutoPage {
                webView.evaluateJavaScript("startAutoPage(\(Int(autoPageInterval.seconds * 1000)))")
            } else {
                webView.evaluateJavaScript("stopAutoPage()")
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onProgressUpdate: onProgressUpdate,
            onTextSelected: onTextSelected,
            onTap: onTap,
            onPageChange: onPageChange,
            onReachChapterStart: onReachChapterStart,
            onReachChapterEnd: onReachChapterEnd,
            onAutoPageEnd: onAutoPageEnd,
            onContentReady: onContentReady,
            onHighlightTap: onHighlightTap,
            onImageTap: onImageTap,
            highlights: highlights
        )
    }

    private func generateHighlightsJSON() -> String {
        let encoder = JSONEncoder()
        struct HighlightData: Encodable {
            let id: String
            let selectedText: String
            let color: String
            let hasNote: Bool
            let notePreview: String?
        }

        let data = highlights.compactMap { highlight -> HighlightData? in
            guard let text = highlight.selectedText, !text.isEmpty else { return nil }
            let color = highlight.highlightColor?.rawValue ?? "yellow"
            let hasNote = highlight.note != nil && !highlight.note!.isEmpty
            let notePreview = hasNote ? String(highlight.note!.prefix(50)) : nil
            return HighlightData(
                id: highlight.id,
                selectedText: text,
                color: color,
                hasNote: hasNote,
                notePreview: notePreview
            )
        }

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "[]"
        }
        return jsonString
    }

    private func generateHTML() -> String { 
        let backgroundColor = theme.backgroundColor.hex
        let textColor = theme.textColor.hex
        let secondaryColor = theme.secondaryTextColor.hex
        let highlightColor = theme.highlightColor.hex
        let linkColor = theme.linkColorHex
        let lineHeight: CGFloat = {
            switch lineSpacing {
            case .compact: return 1.2
            case .normal: return 1.4
            case .relaxed: return 1.6
            case .extraRelaxed: return 1.8
            }
        }()
        let textSize = fontSize.textSize
        let fontFamily = font.cssValue
        let isPaged = readingMode.isPaged
        let isCurlPage = readingMode == .curlPage
        let highlightsJSON = generateHighlightsJSON()

        // Advanced typography values
        let letterSpacingValue = letterSpacing
        let wordSpacingValue = wordSpacing
        let paragraphSpacingValue = paragraphSpacing
        let textAlignValue = textAlignment.cssValue
        let hyphenationValue = hyphenation ? "auto" : "none"
        let fontWeightValue = fontWeight.cssValue

        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                /* ========================================
                   Professional Typography System
                   ======================================== */

                :root {
                    --text-color: \(textColor);
                    --text-secondary: \(secondaryColor);
                    --background: \(backgroundColor);
                    --highlight: \(highlightColor);
                    --link-color: \(linkColor);
                    --font-size: \(textSize)px;
                    --line-height: \(lineHeight);
                    --letter-spacing: \(letterSpacingValue)px;
                    --word-spacing: \(wordSpacingValue)px;
                    --paragraph-spacing: \(paragraphSpacingValue)px;
                    --font-weight: \(fontWeightValue);
                }

                * {
                    -webkit-user-select: text;
                    user-select: text;
                    -webkit-touch-callout: default;
                    box-sizing: border-box;
                }

                /* ========================================
                   Base Typography
                   ======================================== */

                html {
                    font-size: var(--font-size);
                    -webkit-text-size-adjust: 100%;
                    text-size-adjust: 100%;
                }

                body {
                    margin: 0;
                    padding: 20px;
                    padding-top: 60px;
                    padding-bottom: 100px;
                    background-color: var(--background);
                    color: var(--text-color);

                    /* Font Stack - User selected */
                    font-family: \(fontFamily);
                    font-size: 1rem;
                    font-weight: var(--font-weight);
                    line-height: var(--line-height);
                    letter-spacing: var(--letter-spacing);
                    word-spacing: var(--word-spacing);

                    /* Font Rendering Optimization */
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                    text-rendering: optimizeLegibility;

                    /* OpenType Features */
                    font-kerning: normal;
                    font-variant-ligatures: common-ligatures contextual;
                    font-feature-settings: "kern" 1, "liga" 1, "calt" 1;

                    /* Hyphenation */
                    -webkit-hyphens: \(hyphenationValue);
                    hyphens: \(hyphenationValue);
                    -webkit-hyphenate-limit-before: 3;
                    -webkit-hyphenate-limit-after: 2;
                    -webkit-hyphenate-limit-lines: 2;

                    /* Orphans & Widows Control */
                    orphans: 2;
                    widows: 2;

                    /* Word Breaking */
                    word-wrap: break-word;
                    overflow-wrap: break-word;
                }

                /* ========================================
                   Paragraph Styles
                   ======================================== */

                p {
                    margin: 0 0 var(--paragraph-spacing) 0;
                    text-align: \(textAlignValue);
                    text-justify: inter-character;

                    /* First Line Indent */
                    text-indent: 2em;

                    /* Hanging Punctuation */
                    hanging-punctuation: first last allow-end;
                    -webkit-hanging-punctuation: first last allow-end;
                }

                /* First paragraph after headings - no indent */
                h1 + p,
                h2 + p,
                h3 + p,
                h4 + p,
                h5 + p,
                h6 + p,
                blockquote + p,
                .chapter-title + p {
                    text-indent: 0;
                }

                /* First paragraph of chapter with drop cap */
                .chapter-content > p:first-of-type {
                    text-indent: 0;
                }

                /* ========================================
                   Heading Styles
                   ======================================== */

                h1, h2, h3, h4, h5, h6 {
                    font-family: -apple-system, "SF Pro Display", "Helvetica Neue", sans-serif;
                    color: var(--text-color);
                    font-weight: 600;
                    line-height: 1.25;
                    margin-top: 1.5em;
                    margin-bottom: 0.5em;
                    letter-spacing: -0.02em;

                    /* Prevent page break after heading */
                    page-break-after: avoid;
                    break-after: avoid;

                    /* No hyphenation in headings */
                    -webkit-hyphens: none;
                    hyphens: none;
                }

                h1 {
                    font-size: 1.6em;
                    margin-top: 0;
                }

                h2 { font-size: 1.35em; }
                h3 { font-size: 1.15em; }
                h4 { font-size: 1.05em; }

                .chapter-title {
                    text-align: center;
                    margin-bottom: 2em;
                    font-size: 1.4em;
                    letter-spacing: 0;
                }

                /* ========================================
                   Blockquote Styles
                   ======================================== */

                blockquote {
                    margin: 1.5em 0;
                    padding: 0.5em 1.5em;
                    border-left: 3px solid var(--text-secondary);
                    color: var(--text-secondary);
                    font-style: italic;

                    /* Prevent break inside */
                    page-break-inside: avoid;
                    break-inside: avoid;
                }

                blockquote p {
                    text-indent: 0;
                    margin-bottom: 0.5em;
                }

                blockquote p:last-child {
                    margin-bottom: 0;
                }

                /* ========================================
                   Inline Styles
                   ======================================== */

                a {
                    color: var(--link-color);
                    text-decoration: none;
                }

                em, i {
                    font-style: italic;
                }

                strong, b {
                    font-weight: 600;
                }

                /* Small caps for abbreviations */
                abbr {
                    font-variant: small-caps;
                    letter-spacing: 0.05em;
                }

                /* ========================================
                   Lists
                   ======================================== */

                ul, ol {
                    margin: 0.5em 0;
                    padding-left: 2em;
                }

                li {
                    margin-bottom: 0.15em;
                    text-indent: 0;
                    line-height: 1.4;
                }

                li p {
                    text-indent: 0;
                    margin-bottom: 0.15em;
                }

                /* Table of Contents / List styles - compact layout */
                /* Target p tags that only contain links (common TOC pattern) */
                p:has(> a:only-child) {
                    margin-bottom: 0.3em;
                    line-height: 1.3;
                    text-indent: 0;
                }

                /* Consecutive link paragraphs (TOC pattern) */
                p + p:has(a) {
                    margin-top: 0;
                }

                /* Nav element (epub3 TOC) */
                nav ol, nav ul {
                    margin: 0.3em 0;
                    padding-left: 1.5em;
                }

                nav li {
                    margin-bottom: 0.1em;
                    line-height: 1.3;
                }

                /* ========================================
                   Images & Figures
                   ======================================== */

                figure {
                    margin: 1.5em 0;
                    text-align: center;
                    break-inside: avoid;
                    page-break-inside: avoid;
                }

                /* EPUB figcenter class - used for centered figures */
                /* Override inline width styles from EPUB content */
                .figcenter {
                    margin: 1.5em 0;
                    text-align: center;
                    break-inside: avoid;
                    page-break-inside: avoid;
                    max-width: 100% !important;
                    width: auto !important;
                }

                img {
                    max-width: 100%;
                    height: auto;
                    display: block;
                    margin: 0 auto;
                    cursor: pointer;
                    transition: transform 0.15s ease;
                }

                img:active {
                    transform: scale(0.98);
                    opacity: 0.9;
                }

                figcaption {
                    margin-top: 0.5em;
                    font-size: 0.875em;
                    color: var(--text-secondary);
                    font-style: italic;
                    text-indent: 0;
                }

                /* Dropcap images - decorative first letter */
                img.dropcap {
                    float: left;
                    width: auto;
                    height: 2em;
                    margin: 0 0.3em 0.2em 0;
                    display: inline;
                }

                /* Container for dropcap image */
                .dropcap-container {
                    display: inline;
                }

                /* Paragraph following dropcap */
                p.dropcap {
                    text-indent: 0;
                }

                /* Hide first character when dropcap image is present to prevent duplication */
                p.dropcap::first-letter {
                    opacity: 0;
                    font-size: 0;
                    width: 0;
                    margin: 0;
                    padding: 0;
                }

                /* ========================================
                   Code Styles
                   ======================================== */

                code, pre {
                    font-family: "SF Mono", "Menlo", "Monaco", monospace;
                    font-size: 0.9em;
                    font-variant-ligatures: none;
                    -webkit-hyphens: none;
                    hyphens: none;
                }

                code {
                    background-color: rgba(128, 128, 128, 0.1);
                    padding: 0.15em 0.3em;
                    border-radius: 3px;
                }

                pre {
                    margin: 1.5em 0;
                    padding: 1em;
                    background-color: rgba(128, 128, 128, 0.1);
                    overflow-x: auto;
                    line-height: 1.4;
                    border-radius: 6px;
                    white-space: pre-wrap;
                    word-break: break-all;
                }

                pre code {
                    background: none;
                    padding: 0;
                }

                /* ========================================
                   Tables
                   ======================================== */

                table {
                    width: 100%;
                    margin: 1.5em 0;
                    border-collapse: collapse;
                    font-variant-numeric: tabular-nums lining-nums;
                    font-size: 0.5em;
                }

                th, td {
                    padding: 0.5em 0.75em;
                    text-align: left;
                    border-bottom: 1px solid rgba(128, 128, 128, 0.3);
                    text-indent: 0;
                }

                th {
                    font-weight: 600;
                }

                /* TOC / Contents / List tables - compact layout */
                /* Tables with summary attribute (epub TOC pattern) */
                table[summary] {
                    margin: 0.3em 0;
                }

                table[summary] td {
                    padding: 0.02em 0.15em;
                    line-height: 1.1;
                    border-bottom: none;
                    font-size: 0.8em;
                }

                table[summary] tr {
                    line-height: 1.1;
                }

                /* Also support tables with links (fallback) */
                table:has(a) {
                    margin: 0.3em 0;
                }

                table:has(a) td {
                    padding: 0.02em 0.15em;
                    line-height: 1.1;
                    border-bottom: none;
                    font-size: 0.8em;
                }

                table:has(a) tr {
                    line-height: 1.1;
                }

                /* ========================================
                   CJK (Chinese/Japanese/Korean) Support
                   ======================================== */

                /* Chinese text optimization */
                :lang(zh),
                :lang(zh-CN),
                :lang(zh-Hans),
                :lang(zh-Hant) {
                    /* CJK font stack */
                    font-family: "Noto Serif SC", "Source Han Serif SC",
                                 "Songti SC", "STSong", "SimSun",
                                 Georgia, serif;

                    /* Auto spacing between CJK and Latin */
                    text-autospace: ideograph-alpha ideograph-numeric;
                    -webkit-text-autospace: ideograph-alpha ideograph-numeric;

                    /* Disable hyphenation for CJK */
                    -webkit-hyphens: none;
                    hyphens: none;

                    /* Line break rules */
                    line-break: strict;
                    word-break: normal;
                }

                /* ========================================
                   Selection & Highlights
                   ======================================== */

                ::selection {
                    background-color: var(--highlight);
                }

                ::-moz-selection {
                    background-color: var(--highlight);
                }

                .word-highlight {
                    background-color: var(--highlight);
                    border-radius: 2px;
                    padding: 0 2px;
                }

                /* User annotations highlight */
                .user-highlight {
                    border-radius: 2px;
                    padding: 0 1px;
                }

                .user-highlight.yellow { background-color: rgba(255, 235, 59, 0.4); }
                .user-highlight.green { background-color: rgba(76, 175, 80, 0.4); }
                .user-highlight.blue { background-color: rgba(33, 150, 243, 0.4); }
                .user-highlight.pink { background-color: rgba(233, 30, 99, 0.4); }
                .user-highlight.purple { background-color: rgba(156, 39, 176, 0.4); }
                .user-highlight.orange { background-color: rgba(255, 152, 0, 0.4); }

                /* Clickable highlights */
                .user-highlight[data-highlight-id] {
                    cursor: pointer;
                }

                /* Annotation bubble indicator */
                .annotation-indicator {
                    display: inline-flex;
                    align-items: center;
                    justify-content: center;
                    width: 18px;
                    height: 18px;
                    border-radius: 50%;
                    background-color: #FF9800;
                    color: white;
                    font-size: 10px;
                    font-weight: bold;
                    margin-left: 4px;
                    vertical-align: super;
                    cursor: pointer;
                    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.2);
                    transition: transform 0.15s ease;
                }

                .annotation-indicator:active {
                    transform: scale(0.9);
                }

                .annotation-indicator::after {
                    content: "✎";
                    font-size: 10px;
                }

                /* Annotation tooltip preview */
                .annotation-tooltip {
                    position: absolute;
                    background: var(--background);
                    border: 1px solid var(--text-secondary);
                    border-radius: 8px;
                    padding: 8px 12px;
                    max-width: 200px;
                    font-size: 12px;
                    color: var(--text);
                    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
                    z-index: 1000;
                    opacity: 0;
                    pointer-events: none;
                    transition: opacity 0.2s ease;
                }

                .annotation-tooltip.visible {
                    opacity: 1;
                    pointer-events: auto;
                }

                /* ========================================
                   Horizontal Rules
                   ======================================== */

                hr {
                    border: none;
                    border-top: 1px solid var(--text-secondary);
                    margin: 2em 0;
                    opacity: 0.3;
                }

                /* Section break with ornament */
                hr.section-break {
                    border: none;
                    text-align: center;
                    margin: 2em 0;
                }

                hr.section-break::before {
                    content: "* * *";
                    color: var(--text-secondary);
                    letter-spacing: 1em;
                }

                /* ========================================
                   Special Classes
                   ======================================== */

                /* No text indent */
                .no-indent {
                    text-indent: 0 !important;
                }

                /* Centered text */
                .center {
                    text-align: center;
                    text-indent: 0;
                }

                /* Right aligned */
                .right {
                    text-align: right;
                    text-indent: 0;
                }

                /* Small text */
                .small {
                    font-size: 0.875em;
                }

                /* Large text */
                .large {
                    font-size: 1.125em;
                }

                /* Prevent page break */
                .no-break {
                    page-break-inside: avoid;
                    break-inside: avoid;
                }

                /* Drop cap - optional feature */
                .drop-cap::first-letter {
                    float: left;
                    font-size: 3.2em;
                    line-height: 0.85;
                    padding-right: 0.08em;
                    padding-top: 0.05em;
                    font-weight: 600;
                    font-family: Georgia, serif;
                }

                /* ========================================
                   Responsive Adjustments
                   ======================================== */

                @media (max-width: 375px) {
                    body {
                        padding-left: 16px;
                        padding-right: 16px;
                    }

                    p {
                        text-indent: 1.5em;
                    }
                }

                /* ========================================
                   Paged Reading Mode Styles
                   ======================================== */

                \(isPaged ? """
                body.paged-mode {
                    overflow: hidden;
                    height: 100vh;
                    padding: 0;
                }

                .pages-container {
                    display: flex;
                    height: 100vh;
                    transition: transform 0.3s ease-out;
                    /* Hide until pagination is complete to prevent flash */
                    opacity: 0;
                }

                .pages-container.ready {
                    opacity: 1;
                    transition: opacity 0.15s ease-in, transform 0.3s ease-out;
                }

                .page {
                    flex: 0 0 100vw;
                    min-width: 100vw;
                    height: 100vh;
                    padding: 50px 20px 40px 20px;
                    box-sizing: border-box;
                    overflow: hidden;
                    background-color: var(--background);
                }

                .page-content {
                    height: 100%;
                    overflow: hidden;
                }

                .page-indicator {
                    position: fixed;
                    bottom: 12px;
                    right: 16px;
                    font-size: 12px;
                    color: var(--text-secondary);
                    background: var(--background);
                    padding: 4px 12px;
                    border-radius: 12px;
                    z-index: 100;
                }

                /* Curl page animation */
                \(isCurlPage ? """
                .page {
                    transform-style: preserve-3d;
                    backface-visibility: hidden;
                }

                .page.turning-forward {
                    animation: curlForward 0.6s ease-in-out forwards;
                    transform-origin: left center;
                }

                .page.turning-backward {
                    animation: curlBackward 0.6s ease-in-out forwards;
                    transform-origin: right center;
                }

                @keyframes curlForward {
                    0% { transform: rotateY(0deg); }
                    100% { transform: rotateY(-90deg); }
                }

                @keyframes curlBackward {
                    0% { transform: rotateY(0deg); }
                    100% { transform: rotateY(90deg); }
                }
                """ : "")
                """ : "")
            </style>
        </head>
        <body class="\(isPaged ? "paged-mode" : "")">
            \(isPaged ? generatePagedContent() : generateScrollContent())
            <div class="page-indicator" id="pageIndicator" style="display: \(isPaged ? "block" : "none");"></div>

            <script>
                // ========================================
                // Configuration
                // ========================================
                const IS_PAGED = \(isPaged);
                const IS_CURL_PAGE = \(isCurlPage);
                const START_FROM_LAST_PAGE = \(startFromLastPage);
                const SIDE_ZONE_RATIO = 0.25;
                const HIGHLIGHTS_DATA = \(highlightsJSON);

                // ========================================
                // Highlight Rendering (Cross-Paragraph Support)
                // ========================================
                function getTextNodes(root) {
                    const walker = document.createTreeWalker(
                        root,
                        NodeFilter.SHOW_TEXT,
                        null,
                        false
                    );
                    const nodes = [];
                    let node;
                    while (node = walker.nextNode()) {
                        if (node.textContent.trim().length > 0) {
                            nodes.push(node);
                        }
                    }
                    return nodes;
                }

                function findTextAcrossNodes(textNodes, searchText) {
                    // Build combined text with node boundaries
                    let combinedText = '';
                    const nodeMap = []; // Maps character index to {node, offset}

                    textNodes.forEach(node => {
                        const startIndex = combinedText.length;
                        const text = node.textContent;
                        for (let i = 0; i < text.length; i++) {
                            nodeMap.push({ node: node, offset: i });
                        }
                        combinedText += text;
                    });

                    // Find the search text in combined text
                    const searchIndex = combinedText.indexOf(searchText);
                    if (searchIndex === -1) return null;

                    const endIndex = searchIndex + searchText.length - 1;

                    return {
                        start: nodeMap[searchIndex],
                        end: { node: nodeMap[endIndex].node, offset: nodeMap[endIndex].offset + 1 },
                        startIndex: searchIndex,
                        endIndex: endIndex
                    };
                }

                function wrapHighlightSpan(node, startOffset, endOffset, highlightId, color, isLastSegment = true, hasNote = false) {
                    const span = document.createElement('span');
                    span.className = 'user-highlight ' + color;
                    span.dataset.highlightId = highlightId;
                    span.addEventListener('click', function(e) {
                        e.stopPropagation();
                        window.webkit.messageHandlers.highlightTap.postMessage({
                            id: highlightId
                        });
                    });

                    const range = document.createRange();
                    range.setStart(node, startOffset);
                    range.setEnd(node, endOffset);

                    try {
                        range.surroundContents(span);

                        // Add annotation indicator after the last segment if has note
                        if (isLastSegment && hasNote) {
                            const indicator = document.createElement('span');
                            indicator.className = 'annotation-indicator';
                            indicator.dataset.highlightId = highlightId;
                            indicator.addEventListener('click', function(e) {
                                e.stopPropagation();
                                window.webkit.messageHandlers.highlightTap.postMessage({
                                    id: highlightId
                                });
                            });
                            span.insertAdjacentElement('afterend', indicator);
                        }

                        return span;
                    } catch (e) {
                        return null;
                    }
                }

                function applyHighlights() {
                    if (!HIGHLIGHTS_DATA || HIGHLIGHTS_DATA.length === 0) return;

                    const container = document.querySelector('.chapter-content') || document.body;

                    HIGHLIGHTS_DATA.forEach(highlight => {
                        const searchText = highlight.selectedText;
                        if (!searchText) return;

                        // Get fresh text nodes each time (DOM may have changed)
                        const textNodes = getTextNodes(container);
                        const match = findTextAcrossNodes(textNodes, searchText);

                        if (!match) return;

                        const startNode = match.start.node;
                        const startOffset = match.start.offset;
                        const endNode = match.end.node;
                        const endOffset = match.end.offset;
                        const hasNote = highlight.hasNote === true;

                        // Single node case (most common)
                        if (startNode === endNode) {
                            wrapHighlightSpan(startNode, startOffset, endOffset, highlight.id, highlight.color, true, hasNote);
                            return;
                        }

                        // Cross-node case: wrap each node segment separately
                        let inRange = false;
                        const nodesToHighlight = [];

                        for (const node of textNodes) {
                            if (node === startNode) {
                                inRange = true;
                                nodesToHighlight.push({
                                    node: node,
                                    start: startOffset,
                                    end: node.textContent.length
                                });
                            } else if (node === endNode) {
                                nodesToHighlight.push({
                                    node: node,
                                    start: 0,
                                    end: endOffset
                                });
                                break;
                            } else if (inRange) {
                                nodesToHighlight.push({
                                    node: node,
                                    start: 0,
                                    end: node.textContent.length
                                });
                            }
                        }

                        // Apply highlights in reverse order to preserve offsets
                        for (let i = nodesToHighlight.length - 1; i >= 0; i--) {
                            const item = nodesToHighlight[i];
                            const isLast = (i === 0); // First in reverse = last segment
                            wrapHighlightSpan(item.node, item.start, item.end, highlight.id, highlight.color, isLast, hasNote);
                        }
                    });
                }

                // Apply highlights after DOM loads
                document.addEventListener('DOMContentLoaded', function() {
                    setTimeout(applyHighlights, 100);
                });

                // ========================================
                // Paged Mode State
                // ========================================
                let currentPageIndex = 0;
                let totalPages = 1;
                let isAnimating = false;
                let autoPageTimer = null;
                let dragStartX = 0;
                let dragOffset = 0;

                // ========================================
                // Debug Logging Helper
                // ========================================
                function logReaderEvent(category, message, data = {}) {
                    const logData = {
                        category: category,
                        message: message,
                        timestamp: new Date().toISOString(),
                        isPaged: IS_PAGED,
                        currentPage: currentPageIndex,
                        totalPages: totalPages,
                        ...data
                    };
                    console.log('[Reader] ' + category + ': ' + message, logData);

                    // Send to Swift for native logging
                    try {
                        window.webkit.messageHandlers.readerLog.postMessage(logData);
                    } catch(e) {
                        // Handler not registered, ignore
                    }
                }

                // ========================================
                // Text Selection Handling
                // ========================================
                document.addEventListener('selectionchange', function() {
                    const selection = window.getSelection();
                    if (selection && selection.toString().trim().length > 0) {
                        const text = selection.toString().trim();
                        const sentence = getSentenceFromSelection(selection);
                        window.webkit.messageHandlers.textSelection.postMessage({
                            text: text,
                            sentence: sentence
                        });
                    }
                });

                function getSentenceFromSelection(selection) {
                    if (!selection.rangeCount) return '';

                    const range = selection.getRangeAt(0);
                    const node = range.startContainer;

                    if (node.nodeType !== Node.TEXT_NODE) {
                        return selection.toString();
                    }

                    const text = node.textContent;
                    const offset = range.startOffset;

                    let start = offset;
                    let end = offset;

                    while (start > 0 && !'.!?'.includes(text[start - 1])) {
                        start--;
                    }

                    while (end < text.length && !'.!?'.includes(text[end])) {
                        end++;
                    }
                    if (end < text.length) end++;

                    return text.substring(start, end).trim();
                }


                // ========================================
                // Image Tap Handling
                // ========================================
                function getAllImages() {
                    const images = document.querySelectorAll('img');
                    return Array.from(images).map(function(img, index) {
                        const figure = img.closest('figure');
                        const figcaption = figure ? figure.querySelector('figcaption') : null;
                        return {
                            src: img.src,
                            alt: img.alt || null,
                            caption: figcaption ? figcaption.textContent.trim() : null,
                            index: index
                        };
                    });
                }

                // Setup image handling after DOM is ready
                function setupImageHandlers() {
                    const allImages = document.querySelectorAll('img');

                    allImages.forEach(function(img, index) {
                        img.dataset.imageIndex = index;

                        img.addEventListener('click', function(e) {
                            e.preventDefault();
                            e.stopPropagation();

                            const figure = img.closest('figure');
                            const figcaption = figure ? figure.querySelector('figcaption') : null;

                            window.webkit.messageHandlers.imageTap.postMessage({
                                src: img.src,
                                alt: img.alt || null,
                                caption: figcaption ? figcaption.textContent.trim() : null,
                                index: index,
                                allImages: getAllImages()
                            });
                        });
                    });
                }

                // Run image setup after DOM is ready
                if (document.readyState === 'complete' || document.readyState === 'interactive') {
                    setTimeout(setupImageHandlers, 100);
                } else {
                    document.addEventListener('DOMContentLoaded', function() {
                        setTimeout(setupImageHandlers, 100);
                    });
                }

                // ========================================
                // Scroll Mode Handling (vertical scroll)
                // ========================================
                if (!IS_PAGED) {
                    // For scroll mode, content is ready after DOM loads
                    document.addEventListener('DOMContentLoaded', function() {
                        setTimeout(function() {
                            console.log('🟢 [DEBUG] 发送 contentReady 消息到 Swift (滚动模式)');
                            window.webkit.messageHandlers.contentReady.postMessage({});
                        }, 100);
                    });

                    let scrollTimeout = null;
                    window.addEventListener('scroll', function() {
                        if (scrollTimeout) clearTimeout(scrollTimeout);
                        scrollTimeout = setTimeout(function() {
                            const scrollTop = document.documentElement.scrollTop || document.body.scrollTop;
                            const scrollHeight = document.documentElement.scrollHeight - document.documentElement.clientHeight;
                            const progress = scrollHeight > 0 ? scrollTop / scrollHeight : 0;
                            window.webkit.messageHandlers.scroll.postMessage({ progress: progress });
                        }, 100);
                    });

                    // Tap handling for scroll mode
                    let tapTimeout = null;
                    document.addEventListener('touchend', function(e) {
                        if (tapTimeout) clearTimeout(tapTimeout);
                        tapTimeout = setTimeout(function() {
                            const selection = window.getSelection();
                            if (!selection || selection.toString().trim().length === 0) {
                                window.webkit.messageHandlers.tap.postMessage({});
                            }
                        }, 100);
                    });
                }

                // ========================================
                // Paged Mode Handling
                // ========================================
                if (IS_PAGED) {
                    let pagedModeInitialized = false;

                    function initPagedMode() {
                        if (pagedModeInitialized) return;

                        const container = document.querySelector('.pages-container');
                        if (!container) return;

                        pagedModeInitialized = true;
                        const pages = container.querySelectorAll('.page');
                        totalPages = pages.length;

                        // Note: "go to last page" logic moved to paginateContent() where totalPages is accurate
                        updatePageIndicator();
                        notifyPageChange();

                        // Touch/swipe handling on document.body for better coverage
                        document.body.addEventListener('touchstart', handleTouchStart, { passive: true });
                        document.body.addEventListener('touchmove', handleTouchMove, { passive: false });
                        document.body.addEventListener('touchend', handleTouchEnd);

                        // Click handling on document.body for tap zones
                        document.body.addEventListener('click', handleClick);
                    }

                    // Try multiple initialization strategies
                    document.addEventListener('DOMContentLoaded', initPagedMode);

                    // Also try immediately if document is already ready
                    if (document.readyState === 'complete' || document.readyState === 'interactive') {
                        initPagedMode();
                    }

                    // Fallback timeout in case events don't fire
                    setTimeout(initPagedMode, 100);

                    function handleTouchStart(e) {
                        if (isAnimating) return;
                        dragStartX = e.touches[0].clientX;
                        dragOffset = 0;
                    }

                    function handleTouchMove(e) {
                        if (isAnimating) return;
                        e.preventDefault();
                        const currentX = e.touches[0].clientX;
                        dragOffset = currentX - dragStartX;

                        // Calculate visual offset - limit at chapter boundaries to prevent bounce
                        let visualOffset = dragOffset;

                        // First page: limit right drag visual effect (but keep dragOffset for intent)
                        if (currentPageIndex <= 0 && dragOffset > 0) {
                            visualOffset = 0;
                            window.webkit.messageHandlers.readerLog.postMessage('[Reader] At first page, limiting right drag visual');
                        }
                        // Last page: limit left drag visual effect (but keep dragOffset for intent)
                        if (currentPageIndex >= totalPages - 1 && dragOffset < 0) {
                            visualOffset = 0;
                            window.webkit.messageHandlers.readerLog.postMessage('[Reader] At last page, limiting left drag visual');
                        }

                        const container = document.querySelector('.pages-container');
                        const baseOffset = -currentPageIndex * window.innerWidth;
                        container.style.transition = 'none';
                        container.style.transform = `translateX(${baseOffset + visualOffset}px)`;
                    }

                    function handleTouchEnd(e) {
                        const threshold = window.innerWidth * 0.25;
                        const minDragForSnap = 5; // Minimum drag distance to trigger snap animation

                        if (isAnimating) return;

                        if (dragOffset < -threshold) {
                            goToNextPage();
                        } else if (dragOffset > threshold) {
                            goToPreviousPage();
                        } else if (Math.abs(dragOffset) > minDragForSnap) {
                            slideTo(currentPageIndex);
                        }

                        dragOffset = 0;
                    }

                    function handleClick(e) {
                        if (isAnimating) return;
                        if (window.getSelection().toString().trim()) return;

                        const x = e.clientX;
                        const width = window.innerWidth;
                        const leftBoundary = width * SIDE_ZONE_RATIO;
                        const rightBoundary = width * (1 - SIDE_ZONE_RATIO);

                        if (x < leftBoundary) {
                            goToPreviousPage();
                        } else if (x > rightBoundary) {
                            goToNextPage();
                        } else {
                            window.webkit.messageHandlers.tap.postMessage({});
                        }
                    }

                    function goToNextPage() {
                        if (currentPageIndex >= totalPages - 1) {
                            slideTo(currentPageIndex);
                            window.webkit.messageHandlers.navigation.postMessage({ event: 'reachChapterEnd' });
                            return false;
                        }

                        if (IS_CURL_PAGE) {
                            curlPageTurn('forward');
                        } else {
                            currentPageIndex++;
                            slideTo(currentPageIndex);
                        }
                        return true;
                    }

                    function goToPreviousPage() {
                        if (currentPageIndex <= 0) {
                            slideTo(currentPageIndex);
                            window.webkit.messageHandlers.navigation.postMessage({ event: 'reachChapterStart' });
                            return false;
                        }

                        if (IS_CURL_PAGE) {
                            curlPageTurn('backward');
                        } else {
                            currentPageIndex--;
                            slideTo(currentPageIndex);
                        }
                        return true;
                    }

                    function slideTo(pageIndex) {
                        isAnimating = true;
                        const container = document.querySelector('.pages-container');
                        const offset = pageIndex * window.innerWidth;
                        container.style.transition = 'transform 0.3s ease-out';
                        container.style.transform = `translateX(-${offset}px)`;

                        setTimeout(() => {
                            isAnimating = false;
                            updatePageIndicator();
                            notifyPageChange();
                        }, 300);
                    }

                    function curlPageTurn(direction) {
                        isAnimating = true;
                        const pages = document.querySelectorAll('.page');
                        const currentPage = pages[currentPageIndex];

                        if (direction === 'forward') {
                            currentPage.classList.add('turning-forward');
                            setTimeout(() => {
                                currentPage.classList.remove('turning-forward');
                                currentPageIndex++;
                                slideTo(currentPageIndex);
                            }, 600);
                        } else {
                            currentPageIndex--;
                            const prevPage = pages[currentPageIndex];
                            slideTo(currentPageIndex);
                            setTimeout(() => {
                                isAnimating = false;
                            }, 300);
                        }
                    }

                    function updatePageIndicator() {
                        const indicator = document.getElementById('pageIndicator');
                        if (indicator) {
                            indicator.textContent = `${currentPageIndex + 1} / ${totalPages}`;
                        }
                    }

                    function notifyPageChange() {
                        window.webkit.messageHandlers.pageChange.postMessage({
                            current: currentPageIndex + 1,
                            total: totalPages
                        });
                    }

                    // ========================================
                    // Auto Page
                    // ========================================
                    window.startAutoPage = function(intervalMs) {
                        stopAutoPage();
                        autoPageTimer = setInterval(() => {
                            if (!goToNextPage()) {
                                stopAutoPage();
                                window.webkit.messageHandlers.navigation.postMessage({ event: 'autoPageEnd' });
                            }
                        }, intervalMs);
                    };

                    window.stopAutoPage = function() {
                        if (autoPageTimer) {
                            clearInterval(autoPageTimer);
                            autoPageTimer = null;
                        }
                    };
                }
            </script>
        </body>
        </html>
        """
    }

    // MARK: - Content Generation Helpers

    private func generateScrollContent() -> String {
        // Hide title for title pages, cover pages, or empty titles
        let titleLower = content.title.lowercased()
        let shouldHideTitle = content.title.isEmpty ||
                              titleLower.contains("title page") ||
                              titleLower.contains("titlepage") ||
                              titleLower.contains("cover") ||
                              titleLower == "title"

        let titleHtml = shouldHideTitle ? "" : "<h1 class=\"chapter-title\">\(content.title)</h1>"

        // Deduplicate title: remove first h1 if it matches chapter title
        var processedHtmlContent = content.htmlContent
        if !shouldHideTitle && !content.title.isEmpty {
            // Pattern to match first h1 tag at the beginning of content
            let h1Pattern = "^\\s*<h1[^>]*>(.*?)</h1>"
            if let regex = try? NSRegularExpression(pattern: h1Pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: processedHtmlContent, options: [], range: NSRange(processedHtmlContent.startIndex..., in: processedHtmlContent)),
               let h1ContentRange = Range(match.range(at: 1), in: processedHtmlContent) {
                let h1Content = String(processedHtmlContent[h1ContentRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Strip inner tags
                let titleNormalized = content.title.trimmingCharacters(in: .whitespacesAndNewlines)

                // Check if h1 content is similar to title (case-insensitive comparison)
                // Only compare if both h1 and title are non-empty and have sufficient length
                let h1Lower = h1Content.lowercased()
                let titleLower = titleNormalized.lowercased()
                if !h1Lower.isEmpty && !titleLower.isEmpty && h1Lower.count >= 2 && (
                    h1Lower == titleLower ||
                    (h1Lower.count >= 3 && titleLower.contains(h1Lower)) ||
                    (titleLower.count >= 3 && h1Lower.contains(titleLower))
                ) {
                    // Remove the duplicate h1
                    if let fullMatchRange = Range(match.range, in: processedHtmlContent) {
                        processedHtmlContent.removeSubrange(fullMatchRange)
                    }
                }
            }

            // Also remove H2 tags that match chapter title (common in EPUBs)
            let normalizedTitle = content.title.lowercased().filter { $0.isLetter || $0.isNumber }
            let h2Pattern = "<h2[^>]*>([\\s\\S]*?)</h2>"
            if let h2Regex = try? NSRegularExpression(pattern: h2Pattern, options: [.caseInsensitive]) {
                var searchRange = NSRange(processedHtmlContent.startIndex..., in: processedHtmlContent)
                var matches: [NSTextCheckingResult] = []
                while let match = h2Regex.firstMatch(in: processedHtmlContent, options: [], range: searchRange) {
                    matches.append(match)
                    let newStart = match.range.upperBound
                    if newStart < processedHtmlContent.utf16.count {
                        searchRange = NSRange(location: newStart, length: processedHtmlContent.utf16.count - newStart)
                    } else {
                        break
                    }
                }
                // Process matches in reverse order to preserve indices
                for match in matches.reversed() {
                    if let h2ContentRange = Range(match.range(at: 1), in: processedHtmlContent),
                       let fullRange = Range(match.range, in: processedHtmlContent) {
                        let h2Content = String(processedHtmlContent[h2ContentRange])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .lowercased()
                            .filter { $0.isLetter || $0.isNumber }
                        if h2Content == normalizedTitle {
                            processedHtmlContent.removeSubrange(fullRange)
                        }
                    }
                }
            }
        }

        return """
        \(titleHtml)
        <div class="chapter-content">
        \(processedHtmlContent)
        </div>
        """
    }

    private func generatePagedContent() -> String {
        // Hide title for title pages, cover pages, or empty titles
        let titleLower = content.title.lowercased()
        let shouldHideTitle = content.title.isEmpty ||
                              titleLower.contains("title page") ||
                              titleLower.contains("titlepage") ||
                              titleLower.contains("cover") ||
                              titleLower == "title"

        let titleHtml = shouldHideTitle ? "" : "<h1 class=\"chapter-title\">\(content.title)</h1>"

        // Deduplicate title: remove first h1 if it matches chapter title
        var processedHtmlContent = content.htmlContent
        if !shouldHideTitle && !content.title.isEmpty {
            // Pattern to match first h1 tag at the beginning of content
            let h1Pattern = "^\\s*<h1[^>]*>(.*?)</h1>"
            if let regex = try? NSRegularExpression(pattern: h1Pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
               let match = regex.firstMatch(in: processedHtmlContent, options: [], range: NSRange(processedHtmlContent.startIndex..., in: processedHtmlContent)),
               let h1ContentRange = Range(match.range(at: 1), in: processedHtmlContent) {
                let h1Content = String(processedHtmlContent[h1ContentRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) // Strip inner tags
                let titleNormalized = content.title.trimmingCharacters(in: .whitespacesAndNewlines)

                // Check if h1 content is similar to title (case-insensitive comparison)
                // Only compare if both h1 and title are non-empty and have sufficient length
                let h1Lower = h1Content.lowercased()
                let titleLower = titleNormalized.lowercased()
                if !h1Lower.isEmpty && !titleLower.isEmpty && h1Lower.count >= 2 && (
                    h1Lower == titleLower ||
                    (h1Lower.count >= 3 && titleLower.contains(h1Lower)) ||
                    (titleLower.count >= 3 && h1Lower.contains(titleLower))
                ) {
                    // Remove the duplicate h1
                    if let fullMatchRange = Range(match.range, in: processedHtmlContent) {
                        processedHtmlContent.removeSubrange(fullMatchRange)
                    }
                }
            }

            // Also remove H2 tags that match chapter title (common in EPUBs)
            let normalizedTitle = content.title.lowercased().filter { $0.isLetter || $0.isNumber }
            let h2Pattern = "<h2[^>]*>([\\s\\S]*?)</h2>"
            if let h2Regex = try? NSRegularExpression(pattern: h2Pattern, options: [.caseInsensitive]) {
                var searchRange = NSRange(processedHtmlContent.startIndex..., in: processedHtmlContent)
                var matches: [NSTextCheckingResult] = []
                while let match = h2Regex.firstMatch(in: processedHtmlContent, options: [], range: searchRange) {
                    matches.append(match)
                    let newStart = match.range.upperBound
                    if newStart < processedHtmlContent.utf16.count {
                        searchRange = NSRange(location: newStart, length: processedHtmlContent.utf16.count - newStart)
                    } else {
                        break
                    }
                }
                // Process matches in reverse order to preserve indices
                for match in matches.reversed() {
                    if let contentRange = Range(match.range(at: 1), in: processedHtmlContent),
                       let fullRange = Range(match.range, in: processedHtmlContent) {
                        let h2Content = String(processedHtmlContent[contentRange])
                            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                            .lowercased()
                            .filter { $0.isLetter || $0.isNumber }
                        if h2Content == normalizedTitle {
                            processedHtmlContent.removeSubrange(fullRange)
                        }
                    }
                }
            }
        }

        // For paged mode, we wrap content in a pages container
        // The actual pagination happens via JavaScript measuring
        return """
        <div class="pages-container" id="pagesContainer" style="opacity: 0;">
            <div class="page" data-page="0">
                <div class="page-content">
                    \(titleHtml)
                    <div class="chapter-content">
                    \(processedHtmlContent)
                    </div>
                </div>
            </div>
        </div>
        <script>
            // Auto-paginate content after DOM loads
            document.addEventListener('DOMContentLoaded', function() {
                logReaderEvent('Timing', 'DOMContentLoaded fired');
                // Small delay to ensure content is fully rendered
                setTimeout(function() {
                    logReaderEvent('Timing', 'Starting paginateContent after 50ms delay');
                    paginateContent();
                }, 50);
            });

            // Log when page becomes visible
            document.addEventListener('visibilitychange', function() {
                logReaderEvent('Timing', 'Visibility changed: ' + document.visibilityState);
            });

            function paginateContent() {
                logReaderEvent('Timing', 'paginateContent() started');
                const container = document.getElementById('pagesContainer');
                if (!container) {
                    logReaderEvent('Timing', 'ERROR: container not found');
                    return;
                }

                // Log current opacity state
                const computedStyle = window.getComputedStyle(container);
                logReaderEvent('Timing', 'Container opacity at start: ' + computedStyle.opacity + ', hasReady: ' + container.classList.contains('ready'));

                const firstPage = container.querySelector('.page');
                if (!firstPage) return;

                const content = firstPage.querySelector('.page-content');
                if (!content) return;

                const pageHeight = window.innerHeight - 90; // Account for padding (50px top + 40px bottom)
                const pageWidth = window.innerWidth - 40;

                // Clone the content for measurement (must be visible to get correct heights)
                const measureDiv = document.createElement('div');
                measureDiv.style.cssText = 'position: absolute; left: -9999px; top: 0; width: ' + pageWidth + 'px; visibility: visible;';
                measureDiv.innerHTML = content.innerHTML;
                document.body.appendChild(measureDiv);

                // Force layout calculation
                measureDiv.offsetHeight;

                const totalHeight = measureDiv.scrollHeight;
                const numPages = Math.max(1, Math.ceil(totalHeight / pageHeight));

                if (numPages <= 1) {
                    document.body.removeChild(measureDiv);
                    totalPages = 1;
                    logReaderEvent('Pagination', 'Single page', { totalHeight: totalHeight, pageHeight: pageHeight });
                    // Show content for single page - use inline style to override
                    logReaderEvent('Timing', 'Showing content (single page)');
                    requestAnimationFrame(function() {
                        container.style.transition = 'opacity 0.15s ease-in';
                        container.style.opacity = '1';
                        logReaderEvent('Timing', 'Content shown (single page)');

                        // Notify Swift that content is ready and visible
                        setTimeout(function() {
                            console.log('🟢 [DEBUG] 发送 contentReady 消息到 Swift (单页)');
                            window.webkit.messageHandlers.contentReady.postMessage({});
                        }, 200);
                    });
                    return;
                }

                // Get elements for pagination
                // Strategy: Get direct children of chapter-content (the actual content to paginate)
                // This avoids the issue where chapter-content div itself becomes a single paginated element
                const chapterContent = measureDiv.querySelector('.chapter-content');
                const chapterTitle = measureDiv.querySelector('.chapter-title');

                let elements = [];

                // Add chapter title first if it exists
                if (chapterTitle) {
                    elements.push(chapterTitle);
                }

                // Helper function to flatten large elements that exceed page height
                // This recursively extracts children from oversized containers
                function flattenLargeElements(elementList, maxHeight) {
                    const result = [];
                    // Atomic tags that should never be split (media, structural elements that lose meaning when split)
                    const atomicTags = [
                        'IMG', 'SVG', 'PICTURE', 'VIDEO', 'AUDIO', 'CANVAS', 'IFRAME', 'HR', 'BR',
                        'TR', 'TH', 'TD',  // Table rows/cells must stay intact, but TABLE itself can be split
                        'LI', 'DT', 'DD',  // List items must stay intact, but UL/OL can be split
                        'FIGURE', 'FIGCAPTION',  // Figures with captions
                        'PRE', 'CODE',  // Code blocks
                        'BLOCKQUOTE',  // Quotes
                        'RUBY', 'RT', 'RP',  // Asian language annotations
                        'ADDRESS',  // Author/publisher info
                        'MATH',  // MathML formulas
                        'CITE', 'Q',  // Inline quotes
                        'ABBR', 'ACRONYM',  // Abbreviations
                        'FORM', 'SELECT', 'INPUT', 'BUTTON',  // Form elements
                        'DETAILS', 'SUMMARY'  // Collapsible content
                    ];

                    elementList.forEach((el) => {
                        const style = window.getComputedStyle(el);
                        const marginTop = parseFloat(style.marginTop) || 0;
                        const marginBottom = parseFloat(style.marginBottom) || 0;
                        const elHeight = el.offsetHeight + marginTop + marginBottom;

                        // If element fits on a page or is atomic (can't be split), add as-is
                        if (elHeight <= maxHeight || atomicTags.includes(el.tagName) || el.children.length === 0) {
                            result.push(el);
                        } else {
                            // Element is too tall and has children - extract and flatten children
                            logReaderEvent('Pagination', 'Flattening oversized element: ' + el.tagName + ' (height: ' + elHeight + 'px > ' + maxHeight + 'px), children: ' + el.children.length);
                            const children = Array.from(el.children);
                            // Recursively flatten children
                            const flattenedChildren = flattenLargeElements(children, maxHeight);
                            result.push(...flattenedChildren);
                        }
                    });

                    return result;
                }

                // Add direct children of chapter-content for pagination
                if (chapterContent) {
                    // DEBUG: Log the raw HTML content
                    window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] chapterContent.innerHTML length: ' + chapterContent.innerHTML.length);
                    window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] innerHTML preview: ' + chapterContent.innerHTML.substring(0, 500));

                    // Get all direct child nodes (including text nodes)
                    const childNodes = Array.from(chapterContent.childNodes);
                    window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] Total childNodes: ' + childNodes.length);

                    // Convert child nodes to elements, wrapping text nodes in <p> tags
                    const children = [];
                    childNodes.forEach((node, idx) => {
                        const nodeType = node.nodeType === Node.ELEMENT_NODE ? 'ELEMENT' :
                                        node.nodeType === Node.TEXT_NODE ? 'TEXT' : 'OTHER(' + node.nodeType + ')';
                        const preview = node.nodeType === Node.TEXT_NODE ?
                                       node.textContent.substring(0, 100) :
                                       (node.outerHTML ? node.outerHTML.substring(0, 100) : 'no outerHTML');
                        window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] Node[' + idx + '] type=' + nodeType + ' preview: ' + preview);

                        if (node.nodeType === Node.ELEMENT_NODE) {
                            children.push(node);
                        } else if (node.nodeType === Node.TEXT_NODE) {
                            const text = node.textContent.trim();
                            if (text) {
                                // Wrap non-empty text nodes in a paragraph
                                const wrapper = document.createElement('p');
                                wrapper.textContent = text;
                                wrapper.style.margin = '0';
                                children.push(wrapper);
                                window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] Wrapped text: ' + text);
                            }
                        }
                    });

                    window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] Total children after processing: ' + children.length);

                    // Flatten any oversized elements to ensure proper pagination
                    const flattenedElements = flattenLargeElements(children, pageHeight);
                    elements = elements.concat(flattenedElements);
                } else {
                    // Fallback: use old selector-based approach
                    const allElements = measureDiv.querySelectorAll('h1, h2, h3, h4, h5, h6, p, blockquote, pre, ul, ol, li, dl, figure, img, svg, picture, div, section, article, aside, header, footer, main, nav, table, hr');
                    elements = Array.from(allElements).filter((el, index, arr) => {
                        let parent = el.parentElement;
                        while (parent && parent !== measureDiv) {
                            if (arr.includes(parent)) return false;
                            parent = parent.parentElement;
                        }
                        return true;
                    });
                }

                logReaderEvent('Pagination', 'Elements found: ' + elements.length + ', estimated pages: ' + numPages);
                window.webkit.messageHandlers.readerLog.postMessage('[DEBUG] Total elements to paginate: ' + elements.length);

                let currentPageContent = '';
                let currentHeight = 0;
                const pages = [];

                // Track dropcap images and their following elements
                let dropcapIndex = null;
                const skipIndices = new Set();

                // First pass: identify dropcap images and mark following elements
                elements.forEach((el, idx) => {
                    if (el.tagName === 'IMG' && el.className && el.className.includes('dropcap')) {
                        dropcapIndex = idx;
                    }
                    if (dropcapIndex !== null && idx === dropcapIndex + 1) {
                        skipIndices.add(idx);
                        dropcapIndex = null; // Reset after marking
                    }
                });

                // Reset dropcapIndex for main loop
                dropcapIndex = null;

                elements.forEach((el, idx) => {
                    // Skip empty paragraphs
                    const textContent = el.textContent ? el.textContent.trim() : '';
                    if (el.tagName === 'P' && (!textContent || textContent === '\\u00A0')) {
                        return; // Skip empty paragraph
                    }

                    // Get computed height including margins
                    const style = window.getComputedStyle(el);
                    const marginTop = parseFloat(style.marginTop) || 0;
                    const marginBottom = parseFloat(style.marginBottom) || 0;
                    const elHeight = el.offsetHeight + marginTop + marginBottom;

                    // Check if this is a dropcap image
                    if (el.tagName === 'IMG' && el.className && el.className.includes('dropcap')) {
                        dropcapIndex = idx;
                    }

                    // Handle dropcap + following element keeping together
                    if (skipIndices.has(idx) && currentPageContent) {
                        // This element follows a dropcap - check if dropcap + this element fit
                        // If not, start new page for dropcap + this element together
                        const prevEl = elements[idx - 1];
                        if (prevEl) {
                            const prevStyle = window.getComputedStyle(prevEl);
                            const prevMarginTop = parseFloat(prevStyle.marginTop) || 0;
                            const prevMarginBottom = parseFloat(prevStyle.marginBottom) || 0;
                            const prevHeight = prevEl.offsetHeight + prevMarginTop + prevMarginBottom;
                            const combinedDropcapHeight = prevHeight + elHeight;

                            if (currentHeight + combinedDropcapHeight > pageHeight) {
                                // Remove dropcap from current page, start new page
                                // Note: dropcap was already added, so we need to handle this case
                                pages.push(currentPageContent);
                                currentPageContent = prevEl.outerHTML;
                                currentHeight = prevHeight;
                            }
                        }
                    }

                    // Check if this is a cover image (should be on its own page)
                    const isCoverImage = el.tagName === 'IMG' &&
                        (el.className.includes('cover') || el.className.includes('x-ebookmaker-cover'));

                    // Check if element is tall enough to warrant its own page (>80% of page height)
                    const isTallElement = elHeight > pageHeight * 0.8;

                    // Handle TABLE that exceeds page height - split by rows
                    if (el.tagName === 'TABLE' && elHeight > pageHeight) {
                        // First, save any existing content as a page
                        if (currentPageContent) {
                            pages.push(currentPageContent);
                            currentPageContent = '';
                            currentHeight = 0;
                        }

                        // Split table by rows
                        const rows = el.querySelectorAll('tr');
                        let tablePageContent = '';
                        let tablePageHeight = 0;
                        const tableOpenTag = '<table style="' + (el.getAttribute('style') || '') + '" class="' + (el.className || '') + '">';
                        const tableCloseTag = '</table>';

                        rows.forEach((row, rowIdx) => {
                            const rowHeight = row.offsetHeight || 30; // Estimate if not measurable

                            if (tablePageHeight + rowHeight > pageHeight && tablePageContent) {
                                // Save current table page
                                pages.push(tableOpenTag + tablePageContent + tableCloseTag);
                                tablePageContent = '';
                                tablePageHeight = 0;
                            }

                            tablePageContent += row.outerHTML;
                            tablePageHeight += rowHeight;
                        });

                        // Add remaining table content
                        if (tablePageContent) {
                            pages.push(tableOpenTag + tablePageContent + tableCloseTag);
                        }

                        logReaderEvent('Pagination', 'Table split into pages: ' + el.tagName + ' (original height: ' + elHeight + 'px)');
                        return; // Continue to next element
                    }

                    // Cover images get their own page
                    if (isCoverImage) {
                        // First, save any existing content as a page
                        if (currentPageContent) {
                            pages.push(currentPageContent);
                            currentPageContent = '';
                            currentHeight = 0;
                        }
                        // Add this element as its own page
                        pages.push(el.outerHTML);
                        logReaderEvent('Pagination', 'Cover image on own page');
                        return; // Continue to next element
                    }

                    // Handle tall elements that exceed page height
                    if (isTallElement) {
                        // First, save any existing content as a page
                        if (currentPageContent) {
                            pages.push(currentPageContent);
                            currentPageContent = '';
                            currentHeight = 0;
                        }

                        // For tall images, add fit-to-page class
                        if (el.tagName === 'IMG') {
                            el.classList.add('fit-to-page');
                            pages.push(el.outerHTML);
                            logReaderEvent('Pagination', 'Tall image scaled to fit page');
                            return;
                        }

                        // For tall paragraphs/divs, split by text content
                        // Note: This splits EPUB content which is trusted/sanitized at import time
                        if (el.tagName === 'P' || el.tagName === 'DIV') {
                            const elInnerHTML = el.innerHTML;
                            // Split by words while preserving HTML tags
                            const tokens = elInnerHTML.split(/(\\s+|<[^>]+>)/g).filter(t => t);

                            let currentText = '';
                            let splitPages = [];

                            // Create a temporary measure element
                            const tempP = document.createElement(el.tagName);
                            tempP.className = el.className;
                            tempP.style.cssText = 'position: absolute; left: -9999px; width: ' + pageWidth + 'px; visibility: hidden;';
                            document.body.appendChild(tempP);

                            for (let i = 0; i < tokens.length; i++) {
                                const token = tokens[i];
                                const testText = currentText + token;
                                tempP.textContent = ''; // Clear first
                                // Use DOM manipulation for content setting (EPUB content is pre-sanitized at import)
                                const wrapper = document.createElement('div');
                                wrapper.insertAdjacentHTML('beforeend', testText);
                                tempP.appendChild(wrapper);
                                const testHeight = tempP.offsetHeight;
                                tempP.removeChild(wrapper);

                                if (testHeight > pageHeight && currentText.trim()) {
                                    // Current text exceeds page - need to save it
                                    // FIX: Preserve word boundaries - don't split mid-word
                                    let safeText = currentText;
                                    let nextPageStart = token;

                                    // If current token is not whitespace, we might be splitting mid-word
                                    if (!/^\\s+$/.test(token) && !/^<[^>]+>$/.test(token)) {
                                        // Find last whitespace in currentText to break at word boundary
                                        const lastSpaceMatch = currentText.match(/^([\\s\\S]*\\s)(\\S+)$/);
                                        if (lastSpaceMatch && lastSpaceMatch[1].trim()) {
                                            safeText = lastSpaceMatch[1];
                                            nextPageStart = lastSpaceMatch[2] + token;
                                            logReaderEvent('Pagination', 'Word boundary backtrack: moved ' + lastSpaceMatch[2]);
                                        }
                                    }

                                    const pageP = document.createElement(el.tagName);
                                    pageP.className = el.className;
                                    pageP.insertAdjacentHTML('beforeend', safeText.trim());
                                    splitPages.push(pageP.outerHTML);
                                    currentText = nextPageStart;
                                } else {
                                    currentText = testText;
                                }
                            }

                            // Add remaining content
                            if (currentText.trim()) {
                                const pageP = document.createElement(el.tagName);
                                pageP.className = el.className;
                                pageP.insertAdjacentHTML('beforeend', currentText.trim());
                                splitPages.push(pageP.outerHTML);
                            }

                            document.body.removeChild(tempP);

                            // ORPHAN PREVENTION: Check if last page is too small
                            // Note: EPUB content is pre-sanitized at import time
                            if (splitPages.length > 1) {
                                const orphanThreshold = 100; // Minimum height for last part (px)
                                const maxMergeAttempts = 3;
                                let mergeAttempts = 0;

                                // Measure last page height
                                const measureDiv = document.createElement('div');
                                measureDiv.style.cssText = 'position: absolute; left: -9999px; width: ' + pageWidth + 'px; visibility: hidden;';
                                measureDiv.insertAdjacentHTML('beforeend', splitPages[splitPages.length - 1]);
                                document.body.appendChild(measureDiv);
                                let lastPageHeight = measureDiv.offsetHeight;

                                while (lastPageHeight < orphanThreshold && splitPages.length > 1 && mergeAttempts < maxMergeAttempts) {
                                    // Merge last two pages
                                    const lastPage = splitPages.pop();
                                    const secondLast = splitPages.pop();
                                    splitPages.push(secondLast + lastPage);
                                    logReaderEvent('Pagination', 'Orphan prevention: merged last page (was ' + lastPageHeight + 'px)');

                                    // Re-measure
                                    measureDiv.textContent = '';
                                    measureDiv.insertAdjacentHTML('beforeend', splitPages[splitPages.length - 1]);
                                    lastPageHeight = measureDiv.offsetHeight;
                                    mergeAttempts++;
                                }
                                document.body.removeChild(measureDiv);
                            }

                            // Add split pages
                            if (splitPages.length > 0) {
                                splitPages.forEach(p => pages.push(p));
                                logReaderEvent('Pagination', 'Tall text element split into ' + splitPages.length + ' pages');
                            } else {
                                pages.push(el.outerHTML);
                            }
                            return;
                        }

                        // For other tall elements, try to split by children
                        const children = el.children;
                        if (children.length > 1) {
                            let splitPageContent = '';
                            let splitPageHeight = 0;

                            Array.from(children).forEach((child) => {
                                const childStyle = window.getComputedStyle(child);
                                const childMarginTop = parseFloat(childStyle.marginTop) || 0;
                                const childMarginBottom = parseFloat(childStyle.marginBottom) || 0;
                                const childHeight = child.offsetHeight + childMarginTop + childMarginBottom;

                                if (splitPageHeight + childHeight > pageHeight && splitPageContent) {
                                    pages.push(splitPageContent);
                                    splitPageContent = '';
                                    splitPageHeight = 0;
                                }
                                splitPageContent += child.outerHTML;
                                splitPageHeight += childHeight;
                            });

                            if (splitPageContent) {
                                pages.push(splitPageContent);
                            }
                            logReaderEvent('Pagination', 'Tall element split by children');
                        } else {
                            // No children to split, add as is
                            pages.push(el.outerHTML);
                            logReaderEvent('Pagination', 'Tall element on own page: ' + el.tagName + ' (' + elHeight + 'px)');
                        }
                        return; // Continue to next element
                    }

                    // Check if current element is a heading that should stay with next element
                    const isHeading = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6'].includes(el.tagName);
                    const nextEl = elements[idx + 1];
                    let combinedHeight = elHeight;

                    // If heading, calculate combined height with next element
                    if (isHeading && nextEl) {
                        const nextStyle = window.getComputedStyle(nextEl);
                        const nextMarginTop = parseFloat(nextStyle.marginTop) || 0;
                        const nextMarginBottom = parseFloat(nextStyle.marginBottom) || 0;
                        const nextHeight = nextEl.offsetHeight + nextMarginTop + nextMarginBottom;
                        combinedHeight = elHeight + nextHeight;
                    }

                    // Decide if we need a new page
                    if (currentPageContent) {
                        if (isHeading && nextEl) {
                            // For headings: start new page if heading+next won't fit
                            if (currentHeight + combinedHeight > pageHeight) {
                                pages.push(currentPageContent);
                                currentPageContent = '';
                                currentHeight = 0;
                            }
                        } else {
                            // Normal element: start new page if current element won't fit
                            if (currentHeight + elHeight > pageHeight) {
                                pages.push(currentPageContent);
                                currentPageContent = '';
                                currentHeight = 0;
                            }
                        }
                    }

                    currentPageContent += el.outerHTML;
                    currentHeight += elHeight;
                });

                // Add remaining content with HR merge check
                if (currentPageContent) {
                    // Check if remaining content is only HR element(s)
                    const isOnlyHr = currentPageContent.replace(/<hr[^>]*>/gi, '').trim() === '';
                    if (isOnlyHr && pages.length > 0) {
                        // Merge trailing HR with last page to avoid near-empty page
                        pages[pages.length - 1] += currentPageContent;
                        logReaderEvent('Pagination', 'Merged trailing HR with previous page');
                    } else {
                        pages.push(currentPageContent);
                    }
                }

                // Remove measurement div
                document.body.removeChild(measureDiv);

                // Clear container and add pages
                container.innerHTML = '';
                pages.forEach((pageContent, index) => {
                    const pageDiv = createPageDiv(index, pageContent);
                    container.appendChild(pageDiv);
                });

                totalPages = pages.length;
                logReaderEvent('Pagination', 'Complete: ' + totalPages + ' pages from ' + elements.length + ' elements');

                // Handle cross-chapter navigation: go to last page if requested
                // This runs AFTER pagination is complete, so totalPages is accurate
                if (START_FROM_LAST_PAGE && totalPages > 1) {
                    logReaderEvent('Navigation', 'Starting from last page (backward navigation): page ' + totalPages);
                    currentPageIndex = totalPages - 1;
                    // Position immediately without animation for initial load
                    const offset = currentPageIndex * window.innerWidth;
                    container.style.transition = 'none';
                    container.style.transform = 'translateX(-' + offset + 'px)';
                }

                updatePageIndicator();
                notifyPageChange();

                // Show content after pagination and positioning is complete
                // Use inline style to override the initial opacity: 0
                logReaderEvent('Timing', 'Showing content, currentPage: ' + (currentPageIndex + 1) + '/' + totalPages);
                console.log('🟢 [DEBUG] ========== 准备显示内容 ==========');
                console.log('🟢 [DEBUG] 分页完成，总页数: ' + totalPages);
                console.log('🟢 [DEBUG] 当前页码: ' + (currentPageIndex + 1));
                requestAnimationFrame(function() {
                    // Force a reflow to ensure transform is applied before showing
                    container.offsetHeight;
                    container.style.transition = 'opacity 0.15s ease-in';
                    container.style.opacity = '1';
                    console.log('🟢 [DEBUG] ✅ opacity设置为1，内容开始淡入显示');
                    console.log('🟢 [DEBUG] ================================');
                    logReaderEvent('Timing', 'Content shown');

                    // Notify Swift that content is ready and visible
                    setTimeout(function() {
                        console.log('🟢 [DEBUG] 发送 contentReady 消息到 Swift');
                        window.webkit.messageHandlers.contentReady.postMessage({});
                    }, 200); // Small delay to ensure fade-in animation started
                });
            }

            function createPageDiv(index, htmlContent) {
                const pageDiv = document.createElement('div');
                pageDiv.className = 'page';
                pageDiv.dataset.page = index;
                pageDiv.innerHTML = '<div class="page-content">' + htmlContent + '</div>';
                return pageDiv;
            }
        </script>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIScrollViewDelegate, WKUIDelegate {
        var onProgressUpdate: (Double) -> Void
        var onTextSelected: (String, String) -> Void
        var onTap: () -> Void
        var onPageChange: ((Int, Int) -> Void)?
        var onReachChapterStart: (() -> Void)?
        var onReachChapterEnd: (() -> Void)?
        var onAutoPageEnd: (() -> Void)?
        var onContentReady: (() -> Void)?
        var onHighlightTap: ((Bookmark) -> Void)?
        var onImageTap: ((String, String?, [ImageInfo]) -> Void)?
        var highlights: [Bookmark] = []
        weak var webView: WKWebView?
        var lastContentKey: String?

        init(
            onProgressUpdate: @escaping (Double) -> Void,
            onTextSelected: @escaping (String, String) -> Void,
            onTap: @escaping () -> Void,
            onPageChange: ((Int, Int) -> Void)? = nil,
            onReachChapterStart: (() -> Void)? = nil,
            onReachChapterEnd: (() -> Void)? = nil,
            onAutoPageEnd: (() -> Void)? = nil,
            onContentReady: (() -> Void)? = nil,
            onHighlightTap: ((Bookmark) -> Void)? = nil,
            onImageTap: ((String, String?, [ImageInfo]) -> Void)? = nil,
            highlights: [Bookmark] = []
        ) {
            self.onProgressUpdate = onProgressUpdate
            self.onTextSelected = onTextSelected
            self.onTap = onTap
            self.onPageChange = onPageChange
            self.onReachChapterStart = onReachChapterStart
            self.onReachChapterEnd = onReachChapterEnd
            self.onAutoPageEnd = onAutoPageEnd
            self.onContentReady = onContentReady
            self.onHighlightTap = onHighlightTap
            self.onImageTap = onImageTap
            self.highlights = highlights
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // Handle readerLog separately as it can be string or object
            if message.name == "readerLog" {
                if let stringMessage = message.body as? String {
                    // Simple string log
                    print("📖 [ReaderJS] \(stringMessage)")
                    return
                } else if let body = message.body as? [String: Any] {
                    // Object format log
                    let category = body["category"] as? String ?? "Unknown"
                    let logMessage = body["message"] as? String ?? ""
                    let currentPage = body["currentPage"] as? Int ?? 0
                    let totalPages = body["totalPages"] as? Int ?? 0

                    // Log Timing, Pagination and Navigation categories (useful for debugging)
                    if category == "Timing" || category == "Pagination" || category == "Navigation" {
                        print("📖 [ReaderJS] [\(category)] \(logMessage) (page \(currentPage + 1)/\(totalPages))")
                    }
                    return
                }
            }

            guard let body = message.body as? [String: Any] else { return }

            switch message.name {
            case "readerLog":
                break // Already handled above

            case "textSelection":
                if let text = body["text"] as? String,
                   let sentence = body["sentence"] as? String {
                    DispatchQueue.main.async {
                        self.onTextSelected(text, sentence)
                    }
                }

            case "tap":
                DispatchQueue.main.async {
                    self.onTap()
                }

            case "scroll":
                if let progress = body["progress"] as? Double {
                    DispatchQueue.main.async {
                        self.onProgressUpdate(progress)
                    }
                }

            case "pageChange":
                if let current = body["current"] as? Int,
                   let total = body["total"] as? Int {
                    DispatchQueue.main.async {
                        self.onPageChange?(current, total)
                        // Convert page progress to scroll progress for unified tracking
                        let progress = total > 1 ? Double(current - 1) / Double(total - 1) : 0
                        self.onProgressUpdate(progress)
                    }
                }

            case "navigation":
                if let event = body["event"] as? String {
                    DispatchQueue.main.async {
                        switch event {
                        case "reachChapterStart":
                            self.onReachChapterStart?()
                        case "reachChapterEnd":
                            self.onReachChapterEnd?()
                        case "autoPageEnd":
                            self.onAutoPageEnd?()
                        default:
                            break
                        }
                    }
                }

            case "highlightTap":
                if let highlightId = body["id"] as? String {
                    DispatchQueue.main.async {
                        if let highlight = self.highlights.first(where: { $0.id == highlightId }) {
                            self.onHighlightTap?(highlight)
                        }
                    }
                }

            case "imageTap":
                if let src = body["src"] as? String {
                    let alt = body["alt"] as? String
                    let caption = body["caption"] as? String
                    var allImages: [ImageInfo] = []

                    // Parse all images from the message
                    if let images = body["allImages"] as? [[String: Any]] {
                        allImages = images.enumerated().compactMap { index, img in
                            guard let imgSrc = img["src"] as? String else { return nil }
                            return ImageInfo(
                                id: "\(index)",
                                src: imgSrc,
                                alt: img["alt"] as? String,
                                caption: img["caption"] as? String,
                                index: index
                            )
                        }
                    }

                    DispatchQueue.main.async {
                        self.onImageTap?(src, caption ?? alt, allImages)
                    }
                }

            case "contentReady":
                // WebView content is ready and visible
                DispatchQueue.main.async {
                    self.onContentReady?()
                }

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Block external navigation
            if navigationAction.navigationType == .linkActivated {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        // MARK: - WKUIDelegate - Disable context menu
        func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo, completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
            completionHandler(nil)
        }
    }
}

// MARK: - Color Extension

extension Color {
    var hex: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}
