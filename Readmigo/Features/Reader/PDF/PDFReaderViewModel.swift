import Foundation
import PDFKit
import Combine

/// ViewModel for PDF Reader functionality
class PDFReaderViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var document: PDFDocument?
    @Published var isLoading = false
    @Published var error: String?

    @Published var currentPageIndex: Int = 0
    @Published var displayMode: PDFDisplayMode = .singlePageContinuous
    @Published var displayDirection: PDFDisplayDirection = .vertical
    @Published var autoScales: Bool = true

    // MARK: - Computed Properties

    var totalPages: Int {
        document?.pageCount ?? 0
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return Double(currentPageIndex + 1) / Double(totalPages)
    }

    var currentPageText: String? {
        guard let page = document?.page(at: currentPageIndex) else { return nil }
        return page.string
    }

    // MARK: - Initialization

    init() {}

    // MARK: - Public Methods

    /// Load PDF from URL (local or remote)
    func loadPDF(from url: URL) {
        isLoading = true
        error = nil

        // Check if it's a local or remote URL
        if url.isFileURL {
            loadLocalPDF(from: url)
        } else {
            loadRemotePDF(from: url)
        }
    }

    /// Load PDF from Data
    func loadPDF(from data: Data) {
        isLoading = true
        error = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let document = PDFDocument(data: data) {
                DispatchQueue.main.async {
                    self?.document = document
                    self?.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self?.error = "Failed to parse PDF data"
                    self?.isLoading = false
                }
            }
        }
    }

    /// Navigate to specific page
    func goToPage(_ index: Int) {
        guard index >= 0, index < totalPages else { return }
        currentPageIndex = index
    }

    /// Go to next page
    func goToNextPage() {
        if currentPageIndex < totalPages - 1 {
            currentPageIndex += 1
        }
    }

    /// Go to previous page
    func goToPreviousPage() {
        if currentPageIndex > 0 {
            currentPageIndex -= 1
        }
    }

    /// Go to first page
    func goToFirstPage() {
        currentPageIndex = 0
    }

    /// Go to last page
    func goToLastPage() {
        if totalPages > 0 {
            currentPageIndex = totalPages - 1
        }
    }

    /// Search for text in PDF
    func search(text: String) -> [PDFSelection] {
        guard let document = document else { return [] }
        var results: [PDFSelection] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            if let selections = page.findString(text, with: [.caseInsensitive]) {
                results.append(contentsOf: selections)
            }
        }

        return results
    }

    /// Get outline (table of contents) if available
    func getOutline() -> PDFOutline? {
        return document?.outlineRoot
    }

    // MARK: - Private Methods

    private func loadLocalPDF(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let document = PDFDocument(url: url) {
                DispatchQueue.main.async {
                    self?.document = document
                    self?.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self?.error = "Failed to load PDF file"
                    self?.isLoading = false
                }
            }
        }
    }

    private func loadRemotePDF(from url: URL) {
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.error = "Failed to download PDF: \(error.localizedDescription)"
                    self?.isLoading = false
                    return
                }

                guard let data = data else {
                    self?.error = "No data received"
                    self?.isLoading = false
                    return
                }

                if let document = PDFDocument(data: data) {
                    self?.document = document
                    self?.isLoading = false
                } else {
                    self?.error = "Failed to parse downloaded PDF"
                    self?.isLoading = false
                }
            }
        }
        task.resume()
    }
}

// MARK: - PDFOutline Extension

extension PDFOutline {
    /// Convert outline to array of (title, page index) tuples
    func toArray() -> [(title: String, pageIndex: Int)] {
        var items: [(String, Int)] = []

        for i in 0..<numberOfChildren {
            if let child = child(at: i) {
                if let title = child.label,
                   let destination = child.destination,
                   let page = destination.page,
                   let document = page.document,
                   let pageIndex = document.index(for: page) {
                    items.append((title, pageIndex))
                }

                // Recursively add children
                items.append(contentsOf: child.toArray())
            }
        }

        return items
    }
}
