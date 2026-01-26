import SwiftUI

/// A badge that displays the current environment (non-production only)
struct EnvironmentBadge: View {
    @ObservedObject private var environmentManager = EnvironmentManager.shared

    var body: some View {
        #if DEBUG
        if !environmentManager.isProduction {
            badge
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }

    private var badge: some View {
        Text(environmentManager.current.shortName)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(environmentManager.current.color)
            )
    }
}

/// A view modifier that adds an environment badge overlay
struct EnvironmentBadgeModifier: ViewModifier {
    let alignment: Alignment

    func body(content: Content) -> some View {
        content.overlay(alignment: alignment) {
            EnvironmentBadge()
                .padding(8)
        }
    }
}

extension View {
    /// Adds an environment badge overlay to the view
    func environmentBadge(alignment: Alignment = .topTrailing) -> some View {
        modifier(EnvironmentBadgeModifier(alignment: alignment))
    }
}

/// A floating environment indicator that can be placed at the corner of the screen
struct FloatingEnvironmentBadge: View {
    @ObservedObject private var environmentManager = EnvironmentManager.shared
    @State private var showSwitcher = false

    var body: some View {
        #if DEBUG
        if !environmentManager.isProduction {
            Button(action: { showSwitcher = true }) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(environmentManager.current.color)
                        .frame(width: 8, height: 8)

                    Text(environmentManager.current.shortName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                )
            }
            .sheet(isPresented: $showSwitcher) {
                NavigationView {
                    EnvironmentSwitcher()
                        .navigationTitle("Environment")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showSwitcher = false
                                }
                            }
                        }
                }
            }
        } else {
            EmptyView()
        }
        #else
        EmptyView()
        #endif
    }
}

/// Wrapper that shows FloatingEnvironmentBadge in DEBUG builds only
struct EnvironmentBadgeWrapper: View {
    var body: some View {
        #if DEBUG
        FloatingEnvironmentBadge()
            .padding(.top, 60)
            .padding(.leading, 16)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - Preview

#if DEBUG
struct EnvironmentBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Text("Sample Content")
                .padding()
                .background(Color.gray.opacity(0.2))
                .environmentBadge()

            FloatingEnvironmentBadge()
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
