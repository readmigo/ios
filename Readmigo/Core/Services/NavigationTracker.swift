import Foundation
import SwiftUI

/// Tracks page navigation and maintains a page stack for breadcrumb generation
@MainActor
class NavigationTracker: ObservableObject {
    static let shared = NavigationTracker()

    // MARK: - Types

    struct PageInfo {
        let name: String
        let enterTime: Date
        let source: String?
        let metadata: [String: String]
    }

    // MARK: - Properties

    @Published private(set) var pageStack: [PageInfo] = []
    @Published private(set) var breadcrumb: String = ""

    /// Unique session flow ID for this app session
    private(set) var sessionFlowId: String = UUID().uuidString

    /// Maximum pages to keep in stack to prevent memory issues
    private let maxStackSize = 50

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// Push a new page onto the navigation stack
    func pushPage(_ name: String, source: String? = nil, metadata: [String: String] = [:]) {
        let pageInfo = PageInfo(
            name: name,
            enterTime: Date(),
            source: source ?? currentPage(),
            metadata: metadata
        )

        pageStack.append(pageInfo)

        // Trim stack if too large
        if pageStack.count > maxStackSize {
            pageStack.removeFirst(pageStack.count - maxStackSize)
        }

        updateBreadcrumb()
    }

    /// Pop a page from the navigation stack and return its duration
    @discardableResult
    func popPage(_ name: String) -> TimeInterval? {
        // Find the page in stack (search from end)
        guard let index = pageStack.lastIndex(where: { $0.name == name }) else {
            return nil
        }

        let pageInfo = pageStack[index]
        let duration = Date().timeIntervalSince(pageInfo.enterTime)

        // Remove this page and any pages after it
        pageStack.removeSubrange(index...)

        updateBreadcrumb()

        return duration
    }

    /// Get the current (topmost) page name
    func currentPage() -> String? {
        pageStack.last?.name
    }

    /// Get the previous page name (for source tracking)
    func previousPage() -> String? {
        guard pageStack.count >= 2 else { return nil }
        return pageStack[pageStack.count - 2].name
    }

    /// Reset the session flow ID (e.g., on app relaunch)
    func resetSession() {
        sessionFlowId = UUID().uuidString
        pageStack.removeAll()
        breadcrumb = ""
    }

    /// Get a short display name for a page (strips "View" suffix)
    func shortName(for pageName: String) -> String {
        var name = pageName
        if name.hasSuffix("View") {
            name = String(name.dropLast(4))
        }
        return name
    }

    // MARK: - Private Methods

    private func updateBreadcrumb() {
        breadcrumb = pageStack
            .map { shortName(for: $0.name) }
            .joined(separator: " → ")
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension NavigationTracker {
    /// Print current navigation state for debugging
    func debugPrintState() {
        print("""
        [NavigationTracker] Current State:
        ├─ Session: \(sessionFlowId.prefix(8))...
        ├─ Stack Size: \(pageStack.count)
        └─ Breadcrumb: \(breadcrumb)
        """)
    }
}
#endif
