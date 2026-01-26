import SwiftUI

// MARK: - Elegant Refresh Indicator

/// A custom, elegant pull-to-refresh indicator with book-themed animation
struct ElegantRefreshIndicator: View {
    let isRefreshing: Bool
    let progress: CGFloat // 0.0 to 1.0 during pull

    @State private var rotation: Double = 0
    @State private var pageFlip: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Book icon with page flip animation
                BookRefreshIcon(
                    isRefreshing: isRefreshing,
                    progress: progress,
                    pageFlip: pageFlip
                )
                .frame(width: 32, height: 32)
            }

            // Subtle text hint
            if isRefreshing {
                Text("Refreshing...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .scale))
            } else if progress > 0.8 {
                Text("Release to refresh")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onChange(of: isRefreshing) { _, newValue in
            if newValue {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pageFlip = 1
                }
            } else {
                rotation = 0
                pageFlip = 0
            }
        }
    }
}

// MARK: - Book Refresh Icon

private struct BookRefreshIcon: View {
    let isRefreshing: Bool
    let progress: CGFloat
    let pageFlip: Double

    var body: some View {
        ZStack {
            // Book base
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(0.15))
                .frame(width: 24, height: 28)

            // Book spine
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 3, height: 28)
                .offset(x: -10.5)

            // Pages (animated)
            ForEach(0..<3) { index in
                PageView(
                    index: index,
                    isRefreshing: isRefreshing,
                    progress: progress,
                    pageFlip: pageFlip
                )
            }

            // Reading glasses or bookmark accent
            if isRefreshing {
                Circle()
                    .stroke(Color.accentColor, lineWidth: 1.5)
                    .frame(width: 8, height: 8)
                    .offset(x: 4, y: -6)
                    .opacity(0.6)
            }
        }
        .scaleEffect(0.8 + (progress * 0.2))
        .opacity(0.3 + (progress * 0.7))
    }
}

private struct PageView: View {
    let index: Int
    let isRefreshing: Bool
    let progress: CGFloat
    let pageFlip: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.accentColor.opacity(0.4 + Double(index) * 0.2))
            .frame(width: 16, height: 22)
            .rotation3DEffect(
                .degrees(isRefreshing ? (pageFlip * 30 * Double(index + 1)) : (Double(progress) * 15 * Double(index + 1))),
                axis: (x: 0, y: 1, z: 0),
                anchor: .leading,
                perspective: 0.5
            )
            .offset(x: CGFloat(index) * 2 - 2)
    }
}

// MARK: - Refreshable Scroll View

/// A custom ScrollView wrapper with elegant pull-to-refresh
struct ElegantRefreshableScrollView<Content: View>: View {
    let showsIndicators: Bool
    let onRefresh: () async -> Void
    @ViewBuilder let content: Content

    @State private var isRefreshing = false
    @State private var pullProgress: CGFloat = 0

    init(
        showsIndicators: Bool = true,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.showsIndicators = showsIndicators
        self.onRefresh = onRefresh
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: showsIndicators) {
            content
        }
        .refreshable {
            isRefreshing = true
            await onRefresh()
            isRefreshing = false
        }
        // Note: For truly custom refresh UI, we'd need UIViewRepresentable
        // This uses the system refreshable with our styling applied via environment
    }
}

// MARK: - Fully Custom Pull-to-Refresh (UIKit Bridge)

/// A truly custom pull-to-refresh using UIKit's UIRefreshControl
struct CustomRefreshScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    let onRefresh: () async -> Void
    @Binding var isRefreshing: Bool

    init(
        isRefreshing: Binding<Bool>,
        onRefresh: @escaping () async -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self._isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.content = content()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true

        // Add SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        scrollView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        context.coordinator.hostingController = hostingController

        // Custom refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor.tintColor
        refreshControl.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handleRefresh),
            for: .valueChanged
        )
        scrollView.refreshControl = refreshControl
        context.coordinator.refreshControl = refreshControl

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content

        if isRefreshing {
            scrollView.refreshControl?.beginRefreshing()
        } else {
            scrollView.refreshControl?.endRefreshing()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CustomRefreshScrollView
        var hostingController: UIHostingController<Content>?
        var refreshControl: UIRefreshControl?

        init(_ parent: CustomRefreshScrollView) {
            self.parent = parent
        }

        @objc func handleRefresh() {
            Task { @MainActor in
                parent.isRefreshing = true
                await parent.onRefresh()
                parent.isRefreshing = false
                refreshControl?.endRefreshing()
            }
        }
    }
}

// MARK: - Minimal Elegant Refresh Header

/// A minimal, elegant refresh header that appears above content
struct ElegantRefreshHeader: View {
    let isRefreshing: Bool

    var body: some View {
        HStack(spacing: 12) {
            if isRefreshing {
                // Elegant dots animation
                HStack(spacing: 6) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 6, height: 6)
                            .opacity(isRefreshing ? 1 : 0.3)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                                value: isRefreshing
                            )
                            .scaleEffect(isRefreshing ? 1.2 : 0.8)
                    }
                }

                Text("Updating...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: isRefreshing ? 40 : 0)
        .opacity(isRefreshing ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isRefreshing)
    }
}
