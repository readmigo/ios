import SwiftUI

/// ViewModifier that automatically tracks page lifecycle (appear/disappear)
struct PageTrackingModifier: ViewModifier {
    let pageName: String
    let metadata: [String: String]

    @State private var initTime: Date = Date()
    @State private var hasLoggedFirstRender = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                let source = NavigationTracker.shared.previousPage()
                LoggingService.shared.pageEnter(pageName, source: source, metadata: metadata)

                // Log performance on first render
                if !hasLoggedFirstRender {
                    let renderTime = Date().timeIntervalSince(initTime)
                    let memoryMB = LoggingService.currentMemoryMB()
                    LoggingService.shared.pagePerformance(pageName, initToRender: renderTime, memoryMB: memoryMB)
                    hasLoggedFirstRender = true
                }
            }
            .onDisappear {
                LoggingService.shared.pageExit(pageName)
            }
    }
}

// MARK: - View Extension

extension View {
    /// Track page lifecycle with automatic logging
    /// - Parameters:
    ///   - name: The page name to use in logs
    ///   - metadata: Optional metadata to include in page enter logs
    /// - Returns: Modified view with page tracking
    func trackPage(_ name: String, metadata: [String: String] = [:]) -> some View {
        modifier(PageTrackingModifier(pageName: name, metadata: metadata))
    }
}

// MARK: - Performance Only Modifier

/// ViewModifier that only tracks performance metrics without page lifecycle
struct PerformanceTrackingModifier: ViewModifier {
    let pageName: String

    @State private var initTime: Date = Date()
    @State private var hasLogged = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasLogged else { return }
                let renderTime = Date().timeIntervalSince(initTime)
                let memoryMB = LoggingService.currentMemoryMB()
                LoggingService.shared.pagePerformance(pageName, initToRender: renderTime, memoryMB: memoryMB)
                hasLogged = true
            }
    }
}

extension View {
    /// Track only performance metrics (init to render time)
    func trackPerformance(_ name: String) -> some View {
        modifier(PerformanceTrackingModifier(pageName: name))
    }
}

// MARK: - Interaction Tracking

extension View {
    /// Log a user action when this view is tapped
    func trackTap(_ target: String, page: String, metadata: [String: String] = [:]) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                LoggingService.shared.userAction("tap", target: target, page: page, metadata: metadata)
            }
        )
    }
}
