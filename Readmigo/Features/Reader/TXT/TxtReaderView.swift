import SwiftUI

/// TXT Reader View using native SwiftUI text rendering
struct TxtReaderView: View {
    let url: URL
    let title: String

    @StateObject private var viewModel = TxtReaderViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var showChapterList = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background
            themeManager.readerTheme.backgroundColor
                .ignoresSafeArea()

            // Content
            if viewModel.isLoading {
                LoadingView(onClose: { dismiss() })
            } else if let document = viewModel.document {
                TxtContentView(
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
                    TxtTopBar(
                        title: title,
                        onClose: { dismiss() },
                        onChapterList: { showChapterList = true },
                        onSettings: { showSettings = true }
                    )

                    Spacer()

                    // Bottom Bar
                    TxtBottomBar(
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
                TxtChapterListView(
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
            TxtSettingsView(viewModel: viewModel)
                .environmentObject(themeManager)
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

// MARK: - TXT Content View

struct TxtContentView: View {
    let document: ParsedTxtDocument
    @Binding var currentChapterIndex: Int
    let fontSize: CGFloat
    let showControls: Bool
    let onTap: () -> Void

    var currentChapter: ParsedChapter? {
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

                    // Paragraphs
                    ForEach(Array(chapter.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.system(size: fontSize))
                            .lineSpacing(fontSize * 0.5)
                            .padding(.leading, fontSize * 2) // Indent
                    }

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

// MARK: - TXT Top Bar

struct TxtTopBar: View {
    let title: String
    let onClose: () -> Void
    let onChapterList: () -> Void
    let onSettings: () -> Void

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

// MARK: - TXT Bottom Bar

struct TxtBottomBar: View {
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

struct TxtChapterListView: View {
    let chapters: [ParsedChapter]
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

struct TxtSettingsView: View {
    @ObservedObject var viewModel: TxtReaderViewModel
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

// MARK: - Label Style Extension

struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.title
            configuration.icon
        }
    }
}

extension LabelStyle where Self == TrailingIconLabelStyle {
    static var trailingIcon: TrailingIconLabelStyle { .init() }
}
