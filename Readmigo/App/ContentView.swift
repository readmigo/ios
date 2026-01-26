import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if shouldShowOnboarding {
                    OnboardingView()
                        .transition(.opacity)
                } else {
                    mainTabViewContent
                        .transition(.opacity)
                }
            } else if authManager.isGuestMode {
                // Guest mode: allow browsing without login
                mainTabViewContent
                    .transition(.opacity)
            } else {
                AuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showingAuthView)
    }

    /// Single MainTabView instance to prevent recreation during state changes
    @ViewBuilder
    private var mainTabViewContent: some View {
        MainTabView()
            .globalLoginPrompt()
            .id("mainTabView") // Stable ID to prevent recreation
    }

    private var shouldShowOnboarding: Bool {
        // Show onboarding if user is new and hasn't completed onboarding
        authManager.isNewUser && !authManager.hasCompletedOnboarding
    }

    /// Simplified state for animation to prevent excessive view recreation
    private var showingAuthView: Bool {
        !authManager.isAuthenticated && !authManager.isGuestMode
    }
}

struct MainTabView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedTab = 1  // Default to Discover tab

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: tabSelection) {
                LibraryView()
                    .environmentObject(libraryManager)
                    .trackPage("LibraryView")
                    .tabItem {
                        Label("tab.library".localized, systemImage: "books.vertical")
                    }
                    .tag(0)

                DiscoverView()
                    .environmentObject(libraryManager)
                    .trackPage("DiscoverView")
                    .tabItem {
                        Label("tab.discover".localized, systemImage: "storefront")
                    }
                    .tag(1)

                AgoraView()
                    .trackPage("AgoraView")
                    .tabItem {
                        Label("tab.agora".localized, systemImage: "building.columns")
                    }
                    .tag(2)

                MeView()
                    .trackPage("MeView")
                    .tabItem {
                        Label("tab.me".localized, systemImage: "person.circle")
                    }
                    .tag(3)
            }
        }
    }

    /// Custom binding to detect when same tab is tapped again
    private var tabSelection: Binding<Int> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab {
                    // Same tab tapped - trigger scroll to top
                    switch newValue {
                    case 1:
                        NotificationCenter.default.post(name: .discoverTabDoubleTapped, object: nil)
                    case 2:
                        NotificationCenter.default.post(name: .agoraTabDoubleTapped, object: nil)
                    default:
                        break
                    }
                }
                selectedTab = newValue
            }
        )
    }
}

// MARK: - Tab Double-Tap Notifications

extension Notification.Name {
    static let discoverTabDoubleTapped = Notification.Name("discoverTabDoubleTapped")
    static let agoraTabDoubleTapped = Notification.Name("agoraTabDoubleTapped")
}
