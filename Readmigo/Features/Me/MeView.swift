import SwiftUI
import SafariServices

struct MeView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var vocabularyManager = VocabularyManager.shared
    @StateObject private var aboutViewModel = AboutViewModel()
    @ObservedObject private var environmentManager = EnvironmentManager.shared
    @State private var showingReview = false
    @State private var showingEditProfile = false
    @State private var showingSignOutAlert = false
    @State private var showingSafari = false
    @State private var safariURL: URL?
    @State private var showingMessaging = false

    private var isGuest: Bool {
        !authManager.isAuthenticated
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header Card - shows for both logged in and guest users
                    MeProfileCard(
                        user: authManager.currentUser,
                        isGuest: isGuest,
                        onEditTap: { showingEditProfile = true },
                        onLoginTap: { authManager.isGuestMode = false }
                    )

                    // Annual Report Entry Card - Hidden
                    // if authManager.isAuthenticated {
                    //     AnnualReportEntryCard()
                    // }

                    // Menu Sections
                    VStack(spacing: 16) {
                        // Developer Tools Section (debug/staging only)
                        #if DEBUG
                        if !environmentManager.isProduction {
                            MeMenuSection(title: "Developer Tools".localized) {
                                NavigationLink {
                                    DeveloperToolsView()
                                } label: {
                                    MeMenuRow(
                                        icon: "hammer.fill",
                                        iconColor: .orange,
                                        title: "Developer Tools".localized,
                                        subtitle: "me.developerTools.environment".localized(with: environmentManager.current.displayName)
                                    )
                                }
                            }
                        }
                        #endif

                        // Settings Section - Hidden
                        // MeMenuSection(title: "me.section.settings".localized) {
                        //     NavigationLink {
                        //         ReadingSettingsView()
                        //     } label: {
                        //         MeMenuRow(
                        //             icon: "book",
                        //             iconColor: .accentBlue,
                        //             title: "me.readingSettings".localized
                        //         )
                        //     }
                        //
                        //     NavigationLink {
                        //         AppearanceSettingsView()
                        //             .environmentObject(themeManager)
                        //     } label: {
                        //         MeMenuRow(
                        //             icon: "paintbrush",
                        //             iconColor: .accentPink,
                        //             title: "me.appearance".localized
                        //         )
                        //     }
                        //
                        //     NavigationLink {
                        //         NotificationSettingsView()
                        //     } label: {
                        //         MeMenuRow(
                        //             icon: "bell",
                        //             iconColor: .statusError,
                        //             title: "me.notifications".localized
                        //         )
                        //     }
                        //
                        //     NavigationLink {
                        //         OfflineDownloadsView()
                        //     } label: {
                        //         MeMenuRow(
                        //             icon: "arrow.down.circle",
                        //             iconColor: .statusInfo,
                        //             title: "me.downloads".localized
                        //         )
                        //     }
                        // }

                        // Today's Learning Stats - Hidden
                        // if authManager.isAuthenticated {
                        //     TodayStatsCard(stats: vocabularyManager.stats)
                        // }

                        // Quick Actions - Hidden
                        // if authManager.isAuthenticated {
                        //     MeQuickActionsSection(
                        //         dueWords: vocabularyManager.reviewWords.count,
                        //         onReviewTap: { showingReview = true }
                        //     )
                        // }

                        // Contact Us Section
                        MeMenuSection(title: "contact.title".localized) {
                            Button(action: {
                                showingMessaging = true
                            }) {
                                MeMenuRow(
                                    icon: "bubble.left.and.bubble.right",
                                    iconColor: .accentBlue,
                                    title: "contact.sendMessage".localized
                                )
                            }
                        }

                        // Legal Section
                        MeMenuSection(title: "about.legal".localized) {
                            Button(action: {
                                safariURL = aboutViewModel.privacyPolicyURL
                                showingSafari = true
                            }) {
                                MeMenuRow(
                                    icon: "hand.raised",
                                    iconColor: .statusSuccess,
                                    title: "about.privacyPolicy".localized
                                )
                            }

                            Button(action: {
                                safariURL = aboutViewModel.termsOfServiceURL
                                showingSafari = true
                            }) {
                                MeMenuRow(
                                    icon: "doc.text",
                                    iconColor: .accentPurple,
                                    title: "about.termsOfService".localized
                                )
                            }

                            Button(action: {
                                safariURL = aboutViewModel.userAgreementURL
                                showingSafari = true
                            }) {
                                MeMenuRow(
                                    icon: "checkmark.shield",
                                    iconColor: .accentBlue,
                                    title: "about.userAgreement".localized
                                )
                            }
                        }

                        // About Section
                        MeMenuSection(title: "me.section.about".localized) {
                            NavigationLink {
                                AboutView()
                            } label: {
                                MeMenuRow(
                                    icon: "info.circle",
                                    iconColor: .textSecondary,
                                    title: "me.about".localized
                                )
                            }
                        }

                        // Sign Out - only show for logged in users
                        if authManager.isAuthenticated {
                            MeMenuSection(title: "me.section.account".localized) {
                                Button(role: .destructive) {
                                    showingSignOutAlert = true
                                } label: {
                                    MeMenuRow(
                                        icon: "rectangle.portrait.and.arrow.right",
                                        iconColor: .statusError,
                                        title: "me.signOut".localized,
                                        showChevron: false
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("nav.me".localized)
            .navigationBarTitleDisplayMode(.inline)
            .elegantRefreshable {
                await vocabularyManager.fetchStats()
                await vocabularyManager.fetchReviewWords()
            }
            .fullScreenCover(isPresented: $showingReview) {
                ReviewSessionView()
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authManager)
            }
            .alert("me.signOut".localized, isPresented: $showingSignOutAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("me.signOut".localized, role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("me.signOutConfirm".localized)
            }
            .sheet(isPresented: $showingMessaging) {
                MessageListView()
            }
            .sheet(isPresented: $showingSafari) {
                if let url = safariURL {
                    SafariView(url: url)
                }
            }
        }
        .task {
            await vocabularyManager.fetchStats()
            await vocabularyManager.fetchReviewWords()
            await vocabularyManager.fetchVocabulary()
        }
    }
}

// MARK: - Profile Card

private struct MeProfileCard: View {
    let user: User?
    let isGuest: Bool
    let onEditTap: () -> Void
    let onLoginTap: () -> Void

    var body: some View {
        if isGuest {
            // Guest User Card - Not logged in state
            VStack(spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandGradientStart.opacity(0.15),
                                    Color.brandGradientEnd.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.fill")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.textSecondary)
                }

                Text("me.notLoggedIn".localized)
                    .font(.title3)
                    .foregroundColor(.textSecondary)

                // Login Button
                Button(action: onLoginTap) {
                    Text("me.signIn".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.brandGradientStart, .brandGradientMiddle, .brandGradientEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
        } else {
            // Logged In User Card
            HStack(spacing: 16) {
                // Avatar with gradient border
                ZStack {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.brandGradientStart, .brandGradientMiddle, .brandGradientEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 74, height: 74)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.brandGradientStart.opacity(0.2),
                                    Color.brandGradientEnd.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 70, height: 70)
                        .overlay(
                            Text(user?.displayName?.prefix(1).uppercased() ?? "R")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.brandGradientStart, .brandPrimary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(user?.displayName ?? "me.defaultName".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.textPrimary)

                    // English level badge - Hidden for now
                    // if let level = user?.englishLevel {
                    //     Text(level.displayName)
                    //         .font(.caption)
                    //         .fontWeight(.medium)
                    //         .foregroundColor(.white)
                    //         .padding(.horizontal, 10)
                    //         .padding(.vertical, 4)
                    //         .background(
                    //             LinearGradient(
                    //                 colors: [.brandGradientStart, .brandPrimary],
                    //                 startPoint: .leading,
                    //                 endPoint: .trailing
                    //             )
                    //         )
                    //         .cornerRadius(6)
                    // }

                    // Quick stats - Hidden for v1
                    // HStack(spacing: 16) {
                    //     if let booksRead = user?.booksRead {
                    //         Label("me.booksRead".localized(with: booksRead), systemImage: "book.fill")
                    //             .font(.caption)
                    //             .foregroundColor(.textSecondary)
                    //     }
                    //
                    //     if let streak = user?.streak, streak > 0 {
                    //         Label("me.dayStreak".localized(with: streak), systemImage: "flame.fill")
                    //             .font(.caption)
                    //             .foregroundColor(.statusWarning)
                    //     }
                    // }
                }

                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Quick Actions Section

private struct MeQuickActionsSection: View {
    let dueWords: Int
    let onReviewTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("me.quickActions".localized)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                // Review Button
                Button(action: onReviewTap) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("me.review".localized)
                                .fontWeight(.semibold)

                            if dueWords > 0 {
                                Text("me.wordsDue".localized(with: dueWords))
                                    .font(.caption)
                                    .opacity(0.8)
                            } else {
                                Text("me.allCaughtUp".localized)
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(dueWords > 0 ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(dueWords == 0)
            }
        }
    }
}

// MARK: - Menu Section

private struct MeMenuSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Menu Row

private struct MeMenuRow: View {
    let icon: String
    var iconColor: Color = .blue
    let title: String
    var subtitle: String? = nil
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }
}

