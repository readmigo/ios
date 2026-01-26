import SwiftUI
import WebKit

/// MOBI Reader View
struct MobiReaderView: View {
    let url: URL
    let title: String

    @StateObject private var viewModel = MobiReaderViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var showChapterList = false
    @State private var showSettings = false
    @State private var showMetadata = false

    var body: some View {
        ZStack {
            // Background
            themeManager.readerTheme.backgroundColor
                .ignoresSafeArea()

            // Content
            if viewModel.isLoading {
                LoadingView(onClose: { dismiss() })
            } else if let document = viewModel.document {
                MobiContentView(
                    document: document,
                    currentChapterIndex: $viewModel.currentChapterIndex,
                    fontSize: viewModel.fontSize,
                    showControls: showControls,
                    onTap: { toggleControls() }
                )
            } else if let error = viewModel.error {
                ErrorView(
                    message: error,
                    onClose: { dismiss() },
                    onRetry: { viewModel.loadDocument(from: url) }
                )
            }

            // Controls Overlay
            if showControls && !viewModel.isLoading && viewModel.document != nil {
                VStack {
                    // Top Bar
                    MobiTopBar(
                        title: title,
                        onClose: { dismiss() },
                        onChapterList: { showChapterList = true },
                        onSettings: { showSettings = true },
                        onMetadata: { showMetadata = true }
                    )

                    Spacer()

                    // Bottom Bar
                    MobiBottomBar(
                        currentChapter: viewModel.currentChapterIndex + 1,
                        totalChapters: viewModel.document?.chapters.count ?? 0,
                        onPrevious: { viewModel.previousChapter() },
                        onNext: { viewModel.nextChapter() }
                    )
                }
            }
        }
        .preferredColorScheme(themeManager.readerTheme == .dark ? .dark : .light)
        .sheet(isPresented: $showChapterList) {
            if let document = viewModel.document {
                MobiChapterListView(
                    chapters: document.chapters,
                    currentChapter: viewModel.currentChapterIndex,
                    onSelect: { index in
                        viewModel.goToChapter(index)
                        showChapterList = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            MobiSettingsView(viewModel: viewModel)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showMetadata) {
            if let metadata = viewModel.metadata {
                MobiMetadataView(metadata: metadata)
            }
        }
        .onAppear {
            viewModel.loadDocument(from: url)
        }
        .statusBarHidden(!showControls)
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
    }
}

// MARK: - Loading View

private struct LoadingView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("reader.loadingMobi".localized)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Error View

private struct ErrorView: View {
    let message: String
    let onClose: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(spacing: 20) {
                Button("common.close".localized) { onClose() }
                    .buttonStyle(.bordered)
                Button("common.retry".localized) { onRetry() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - MOBI Content View

struct MobiContentView: View {
    let document: ParsedMobiDocument
    @Binding var currentChapterIndex: Int
    let fontSize: CGFloat
    let showControls: Bool
    let onTap: () -> Void

    var currentChapter: ParsedMobiChapter? {
        guard currentChapterIndex >= 0 && currentChapterIndex < document.chapters.count else {
            return nil
        }
        return document.chapters[currentChapterIndex]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let chapter = currentChapter {
                    // Chapter Title
                    Text(chapter.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.bottom, 8)

                    // Content (render as attributed text from HTML)
                    MobiHtmlContentView(html: chapter.html, fontSize: fontSize)

                    // Chapter Navigation
                    HStack {
                        if currentChapterIndex > 0 {
                            Button {
                                withAnimation {
                                    currentChapterIndex -= 1
                                }
                            } label: {
                                Label("reader.previous".localized, systemImage: "chevron.left")
                            }
                        }

                        Spacer()

                        if currentChapterIndex < document.chapters.count - 1 {
                            Button {
                                withAnimation {
                                    currentChapterIndex += 1
                                }
                            } label: {
                                Label("reader.next".localized, systemImage: "chevron.right")
                                    .labelStyle(.trailingIcon)
                            }
                        }
                    }
                    .padding(.top, 32)
                }
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - MOBI HTML Content View

struct MobiHtmlContentView: UIViewRepresentable {
    let html: String
    let fontSize: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHtml = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    font-size: \(fontSize)px;
                    line-height: 1.8;
                    color: #333;
                    background-color: transparent;
                    margin: 0;
                    padding: 0;
                }
                @media (prefers-color-scheme: dark) {
                    body { color: #e0e0e0; }
                }
                p { text-indent: 2em; margin: 0.8em 0; }
                img { max-width: 100%; height: auto; }
                h1, h2, h3, h4, h5, h6 { margin-top: 1.5em; margin-bottom: 0.5em; }
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """

        webView.loadHTMLString(styledHtml, baseURL: nil)
    }
}

// MARK: - MOBI Top Bar

struct MobiTopBar: View {
    let title: String
    let onClose: () -> Void
    let onChapterList: () -> Void
    let onSettings: () -> Void
    let onMetadata: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 4) {
                Button(action: onMetadata) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }

                Button(action: onChapterList) {
                    Image(systemName: "list.bullet")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                        .foregroundColor(.primary)
                        .frame(width: 44, height: 44)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Rectangle())
    }
}

// MARK: - MOBI Bottom Bar

struct MobiBottomBar: View {
    let currentChapter: Int
    let totalChapters: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var progress: Double {
        guard totalChapters > 0 else { return 0 }
        return Double(currentChapter) / Double(totalChapters)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 4)
                }
                .cornerRadius(2)
            }
            .frame(height: 4)
            .padding(.horizontal)

            HStack {
                Button(action: onPrevious) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("reader.previous".localized)
                    }
                    .font(.subheadline)
                    .foregroundColor(currentChapter > 1 ? .primary : .gray)
                }
                .disabled(currentChapter <= 1)

                Spacer()

                Text("\(currentChapter) / \(totalChapters)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(action: onNext) {
                    HStack(spacing: 4) {
                        Text("reader.next".localized)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(currentChapter < totalChapters ? .primary : .gray)
                }
                .disabled(currentChapter >= totalChapters)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Rectangle())
    }
}

// MARK: - Chapter List View

struct MobiChapterListView: View {
    let chapters: [ParsedMobiChapter]
    let currentChapter: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                    Button {
                        onSelect(index)
                    } label: {
                        HStack {
                            Text("\(index + 1).")
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .leading)

                            Text(chapter.title)
                                .foregroundColor(index == currentChapter ? .blue : .primary)
                                .fontWeight(index == currentChapter ? .semibold : .regular)

                            Spacer()

                            if index == currentChapter {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("reader.chapters".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings View

struct MobiSettingsView: View {
    @ObservedObject var viewModel: MobiReaderViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("reader.settings.fontSize".localized) {
                    HStack {
                        Text("A")
                            .font(.system(size: 14))

                        Slider(
                            value: $viewModel.fontSize,
                            in: 14...32,
                            step: 2
                        )

                        Text("A")
                            .font(.system(size: 24))
                    }

                    Text("\(Int(viewModel.fontSize)) pt")
                        .foregroundColor(.secondary)
                }

                Section("reader.goToChapter".localized) {
                    if let document = viewModel.document {
                        Picker("reader.chapter".localized, selection: $viewModel.currentChapterIndex) {
                            ForEach(0..<document.chapters.count, id: \.self) { index in
                                Text(document.chapters[index].title)
                                    .tag(index)
                            }
                        }
                    }
                }
            }
            .navigationTitle("reader.readingSettings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Metadata View

struct MobiMetadataView: View {
    let metadata: MobiMetadata
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("reader.bookInformation".localized) {
                    LabeledContent("reader.metadata.title".localized, value: metadata.title)
                    LabeledContent("reader.metadata.author".localized, value: metadata.author)
                    if !metadata.publisher.isEmpty {
                        LabeledContent("reader.metadata.publisher".localized, value: metadata.publisher)
                    }
                    LabeledContent("reader.metadata.language".localized, value: metadata.language)
                    if !metadata.isbn.isEmpty {
                        LabeledContent("reader.metadata.isbn".localized, value: metadata.isbn)
                    }
                }

                if !metadata.description.isEmpty {
                    Section("reader.metadata.description".localized) {
                        Text(metadata.description)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("reader.bookInfo".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Label Style Extension

private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

private extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { .init() }
}
