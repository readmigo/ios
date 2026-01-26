import SwiftUI
import PDFKit

/// PDF Reader using PDFKit for rendering and navigation
struct PDFReaderView: View {
    let url: URL
    let title: String

    @StateObject private var viewModel = PDFReaderViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showControls = true
    @State private var showThumbnails = false
    @State private var showSettings = false
    @State private var hideControlsTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            // Background
            themeManager.readerTheme.backgroundColor
                .ignoresSafeArea()

            // PDF Content
            if viewModel.isLoading {
                LoadingView(onClose: { dismiss() })
            } else if let document = viewModel.document {
                PDFKitView(
                    document: document,
                    displayMode: viewModel.displayMode,
                    displayDirection: viewModel.displayDirection,
                    autoScales: viewModel.autoScales,
                    currentPage: $viewModel.currentPageIndex,
                    onTap: { toggleControls() }
                )
                .ignoresSafeArea(.all, edges: .bottom)
            } else if let error = viewModel.error {
                ErrorView(
                    message: error,
                    onClose: { dismiss() },
                    onRetry: { viewModel.loadPDF(from: url) }
                )
            }

            // Controls Overlay
            if showControls && !viewModel.isLoading && viewModel.document != nil {
                VStack {
                    // Top Bar
                    PDFTopBar(
                        title: title,
                        onClose: { dismiss() },
                        onThumbnails: { showThumbnails = true },
                        onSettings: { showSettings = true }
                    )

                    Spacer()

                    // Bottom Bar
                    PDFBottomBar(
                        currentPage: viewModel.currentPageIndex + 1,
                        totalPages: viewModel.totalPages,
                        onPrevious: { viewModel.goToPreviousPage() },
                        onNext: { viewModel.goToNextPage() },
                        onPageSelect: { page in
                            viewModel.goToPage(page - 1)
                        }
                    )
                }
            }
        }
        .preferredColorScheme(themeManager.readerTheme == .dark ? .dark : .light)
        .sheet(isPresented: $showThumbnails) {
            if let document = viewModel.document {
                PDFThumbnailsView(
                    document: document,
                    currentPage: viewModel.currentPageIndex,
                    onSelect: { page in
                        viewModel.goToPage(page)
                        showThumbnails = false
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            PDFSettingsView(viewModel: viewModel)
                .environmentObject(themeManager)
        }
        .onAppear {
            viewModel.loadPDF(from: url)
        }
        .statusBarHidden(!showControls)
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }

        if showControls {
            scheduleHideControls()
        } else {
            hideControlsTask?.cancel()
        }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation {
                    showControls = false
                }
            }
        }
    }
}

// MARK: - PDFKit SwiftUI Wrapper

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    let displayMode: PDFDisplayMode
    let displayDirection: PDFDisplayDirection
    let autoScales: Bool
    @Binding var currentPage: Int
    let onTap: () -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.displayMode = displayMode
        pdfView.displayDirection = displayDirection
        pdfView.autoScales = autoScales
        pdfView.backgroundColor = .clear
        pdfView.pageBreakMargins = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        tapGesture.numberOfTapsRequired = 1
        pdfView.addGestureRecognizer(tapGesture)

        // Observe page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        context.coordinator.pdfView = pdfView
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.displayMode = displayMode
        pdfView.displayDirection = displayDirection
        pdfView.autoScales = autoScales

        // Navigate to page if changed externally
        if let page = document.page(at: currentPage), pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: PDFKitView
        weak var pdfView: PDFView?

        init(_ parent: PDFKitView) {
            self.parent = parent
        }

        @objc func handleTap() {
            parent.onTap()
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = pdfView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPage) else { return }

            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
}

// MARK: - PDF Top Bar

struct PDFTopBar: View {
    let title: String
    let onClose: () -> Void
    let onThumbnails: () -> Void
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
                Button(action: onThumbnails) {
                    Image(systemName: "square.grid.2x2")
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

// MARK: - PDF Bottom Bar

struct PDFBottomBar: View {
    let currentPage: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onPageSelect: (Int) -> Void

    @State private var showPagePicker = false

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPage) / Double(totalPages)
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
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(currentPage > 1 ? .primary : .gray)
                }
                .disabled(currentPage <= 1)
                .frame(width: 44, height: 44)

                Spacer()

                Button {
                    showPagePicker = true
                } label: {
                    Text("\(currentPage) / \(totalPages)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .sheet(isPresented: $showPagePicker) {
                    PagePickerView(
                        currentPage: currentPage,
                        totalPages: totalPages,
                        onSelect: { page in
                            onPageSelect(page)
                            showPagePicker = false
                        }
                    )
                }

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(currentPage < totalPages ? .primary : .gray)
                }
                .disabled(currentPage >= totalPages)
                .frame(width: 44, height: 44)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Rectangle())
    }
}

// MARK: - Page Picker

struct PagePickerView: View {
    let currentPage: Int
    let totalPages: Int
    let onSelect: (Int) -> Void

    @State private var selectedPage: Int
    @Environment(\.dismiss) private var dismiss

    init(currentPage: Int, totalPages: Int, onSelect: @escaping (Int) -> Void) {
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.onSelect = onSelect
        _selectedPage = State(initialValue: currentPage)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("reader.goToPage".localized)
                    .font(.headline)

                Picker("reader.page".localized, selection: $selectedPage) {
                    ForEach(1...totalPages, id: \.self) { page in
                        Text("\(page)").tag(page)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 150)

                Button("reader.go".localized) {
                    onSelect(selectedPage)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("reader.selectPage".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}

// MARK: - PDF Settings View

struct PDFSettingsView: View {
    @ObservedObject var viewModel: PDFReaderViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("reader.pdf.displayMode".localized) {
                    Picker("reader.pdf.pageMode".localized, selection: $viewModel.displayMode) {
                        Text("reader.pdf.singlePage".localized).tag(PDFDisplayMode.singlePage)
                        Text("reader.pdf.singleContinuous".localized).tag(PDFDisplayMode.singlePageContinuous)
                        Text("reader.pdf.twoUp".localized).tag(PDFDisplayMode.twoUp)
                        Text("reader.pdf.twoUpContinuous".localized).tag(PDFDisplayMode.twoUpContinuous)
                    }
                }

                Section("reader.pdf.scrollDirection".localized) {
                    Picker("reader.pdf.direction".localized, selection: $viewModel.displayDirection) {
                        Text("reader.pdf.vertical".localized).tag(PDFDisplayDirection.vertical)
                        Text("reader.pdf.horizontal".localized).tag(PDFDisplayDirection.horizontal)
                    }
                    .pickerStyle(.segmented)
                }

                Section("reader.pdf.zoom".localized) {
                    Toggle("reader.pdf.autoScale".localized, isOn: $viewModel.autoScales)
                }
            }
            .navigationTitle("reader.pdf.settings".localized)
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

// MARK: - PDF Thumbnails View

struct PDFThumbnailsView: View {
    let document: PDFDocument
    let currentPage: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(0..<document.pageCount, id: \.self) { index in
                        Button {
                            onSelect(index)
                        } label: {
                            VStack(spacing: 8) {
                                PDFThumbnailView(document: document, pageIndex: index)
                                    .frame(width: 100, height: 140)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(index == currentPage ? Color.blue : Color.clear, lineWidth: 3)
                                    )

                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(index == currentPage ? .blue : .secondary)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("reader.pages".localized)
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

// MARK: - PDF Thumbnail View

struct PDFThumbnailView: UIViewRepresentable {
    let document: PDFDocument
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFThumbnailView_UIKit {
        let thumbnailView = PDFThumbnailView_UIKit()
        thumbnailView.backgroundColor = .systemBackground
        return thumbnailView
    }

    func updateUIView(_ uiView: PDFThumbnailView_UIKit, context: Context) {
        if let page = document.page(at: pageIndex) {
            uiView.page = page
        }
    }
}

class PDFThumbnailView_UIKit: UIView {
    var page: PDFPage? {
        didSet {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let page = page, let context = UIGraphicsGetCurrentContext() else { return }

        // White background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(rect)

        // Get page bounds
        let pageRect = page.bounds(for: .mediaBox)

        // Calculate scale to fit
        let scaleX = rect.width / pageRect.width
        let scaleY = rect.height / pageRect.height
        let scale = min(scaleX, scaleY)

        // Center the page
        let scaledWidth = pageRect.width * scale
        let scaledHeight = pageRect.height * scale
        let offsetX = (rect.width - scaledWidth) / 2
        let offsetY = (rect.height - scaledHeight) / 2

        context.saveGState()
        context.translateBy(x: offsetX, y: rect.height - offsetY)
        context.scaleBy(x: scale, y: -scale)

        page.draw(with: .mediaBox, to: context)

        context.restoreGState()
    }
}
