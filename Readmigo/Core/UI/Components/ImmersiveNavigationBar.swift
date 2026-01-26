import SwiftUI

// MARK: - Immersive Navigation Bar

/// A custom frosted glass navigation bar that fades in as user scrolls
@available(iOS 18.0, *)
struct ImmersiveNavigationBar: View {
    let title: String
    let titleOpacity: Double
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Back button with circular background for visibility
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }

                // Title (fades in on scroll)
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(titleOpacity)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .padding(.top, safeAreaTop)
            .background(
                // Frosted glass background (opacity changes with scroll)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(titleOpacity)
            )

            // Divider line
            Divider()
                .opacity(titleOpacity)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
}

// MARK: - Fallback for iOS 17 and below

struct ImmersiveNavigationBarFallback: View {
    let title: String
    let titleOpacity: Double
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }

                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(titleOpacity)

                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .padding(.top, safeAreaTop)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(titleOpacity)
            )

            Divider()
                .opacity(titleOpacity)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
}

// MARK: - Swipe Back Gesture Enabler

/// Re-enables the interactive pop gesture when navigation bar is hidden
struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackGestureController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private class SwipeBackGestureController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}

extension View {
    /// Enables swipe back gesture when navigation bar is hidden
    func enableSwipeBack() -> some View {
        background(SwipeBackGestureEnabler())
    }
}
