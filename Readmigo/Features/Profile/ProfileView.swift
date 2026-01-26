import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingEditProfile = false
    @State private var showingSettings = false
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false

    var body: some View {
        NavigationStack {
            List {
                // Profile Header
                Section {
                    ProfileHeaderView(user: authManager.currentUser)
                        .onTapGesture {
                            showingEditProfile = true
                        }
                }

                // Stats Section
                if let user = authManager.currentUser {
                    Section("profile.section.readingStats".localized) {
                        StatsRow(icon: "book.fill", title: "profile.booksRead".localized, value: "\(user.booksRead)")
                        StatsRow(icon: "clock.fill", title: "profile.readingTime".localized, value: formatMinutes(user.totalReadingMinutes))
                        StatsRow(icon: "text.word.spacing", title: "profile.wordsLearned".localized, value: "\(user.wordsLearned)")
                        StatsRow(icon: "flame.fill", title: "profile.streak".localized, value: "profile.streakDays".localized(with: user.streak))

                        NavigationLink {
                            StatsView()
                        } label: {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("profile.viewDetailedStats".localized)
                                Spacer()
                            }
                        }
                    }
                }

                // Badges Section
                Section("profile.section.achievements".localized) {
                    NavigationLink {
                        BadgesView()
                    } label: {
                        HStack {
                            Image(systemName: "medal.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("profile.myBadges".localized)
                            Spacer()
                        }
                    }
                }

                // Settings Section
                Section("profile.section.settings".localized) {
                    NavigationLink {
                        ReadingSettingsView()
                    } label: {
                        SettingsRow(icon: "book", title: "settings.reading".localized)
                    }

                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsRow(icon: "bell", title: "settings.notifications".localized)
                    }

                    NavigationLink {
                        AppearanceSettingsView()
                            .environmentObject(themeManager)
                    } label: {
                        SettingsRow(icon: "paintbrush", title: "settings.appearance".localized)
                    }

                    NavigationLink {
                        OfflineDownloadsView()
                    } label: {
                        SettingsRow(icon: "arrow.down.circle", title: "settings.downloads".localized)
                    }

                    NavigationLink {
                        OfflineSettingsView()
                    } label: {
                        SettingsRow(icon: "wifi.slash", title: "settings.offline".localized)
                    }
                }

                // Subscription Section
                Section("profile.section.subscription".localized) {
                    NavigationLink {
                        SubscriptionStatusView()
                    } label: {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                                .frame(width: 24)

                            Text("profile.manageSubscription".localized)

                            Spacer()

                            if authManager.currentUser?.subscriptionTier == .premium {
                                Text("subscription.premium".localized)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.yellow)
                                    .cornerRadius(4)
                            } else if authManager.currentUser?.subscriptionTier == .pro {
                                Text("subscription.pro".localized)
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                // Postcards Section
                Section("profile.section.creative".localized) {
                    NavigationLink {
                        PostcardsView()
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            Text("profile.myPostcards".localized)
                            Spacer()
                        }
                    }

                    NavigationLink {
                        QuotesView()
                    } label: {
                        HStack {
                            Image(systemName: "text.quote")
                                .foregroundColor(.indigo)
                                .frame(width: 24)
                            Text("profile.quotes".localized)
                            Spacer()
                        }
                    }
                }

                // Support Section
                Section("profile.section.support".localized) {
                    NavigationLink {
                        HelpCenterView()
                    } label: {
                        SettingsRow(icon: "questionmark.circle", title: "support.helpCenter".localized)
                    }

                    Button {
                        if let url = URL(string: "mailto:support@readmigo.app") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        SettingsRow(icon: "envelope", title: "support.contactUs".localized)
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(icon: "info.circle", title: "support.about".localized)
                    }
                }

                // Account Section
                Section("profile.section.account".localized) {
                    NavigationLink {
                        AccountSettingsView()
                            .environmentObject(authManager)
                    } label: {
                        SettingsRow(icon: "person.crop.circle", title: "profile.accountSettings".localized)
                    }
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        showingSignOutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("auth.signOut".localized)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("nav.profile".localized)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView()
                    .environmentObject(authManager)
            }
            .alert("auth.signOut".localized, isPresented: $showingSignOutAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("auth.signOut".localized, role: .destructive) {
                    Task {
                        await authManager.signOut()
                    }
                }
            } message: {
                Text("auth.signOutConfirm".localized)
            }
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User?

    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(user?.displayName?.prefix(1).uppercased() ?? "?")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName ?? "profile.defaultName".localized)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let level = user?.englishLevel {
                    Text(level.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Stats Row

struct StatsRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)

            Spacer()

            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            Text(title)
        }
    }
}

// MARK: - Edit Profile

struct EditProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var selectedLevel: EnglishLevel = .intermediate
    @State private var dailyGoal = 30
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section("profile.edit.displayName".localized) {
                    TextField("profile.edit.namePlaceholder".localized, text: $displayName)
                }

                Section("profile.edit.englishLevel".localized) {
                    Picker("profile.edit.level".localized, selection: $selectedLevel) {
                        ForEach(EnglishLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("profile.edit.dailyGoal".localized) {
                    Stepper("profile.edit.goalMinutes".localized(with: dailyGoal), value: $dailyGoal, in: 5...120, step: 5)
                }
            }
            .navigationTitle("profile.edit.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        Task { await saveProfile() }
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                if let user = authManager.currentUser {
                    displayName = user.displayName ?? ""
                    selectedLevel = user.englishLevel ?? .intermediate
                    dailyGoal = user.dailyGoalMinutes
                }
            }
        }
    }

    private func saveProfile() async {
        isLoading = true

        do {
            try await authManager.updateProfile(
                displayName: displayName.isEmpty ? nil : displayName,
                englishLevel: selectedLevel,
                dailyGoalMinutes: dailyGoal
            )
            dismiss()
        } catch {
            print("Failed to update profile: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Placeholder Views

struct ReadingSettingsView: View {
    var body: some View {
        List {
            Section {
                Toggle("settings.autoBookmark".localized, isOn: .constant(true))
                Toggle("settings.syncDevices".localized, isOn: .constant(true))
            }

            Section("settings.readingReminders".localized) {
                Toggle("settings.dailyReminder".localized, isOn: .constant(false))
            }
        }
        .navigationTitle("settings.reading".localized)
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        List {
            Toggle("settings.reviewReminder".localized, isOn: .constant(true))
            Toggle("settings.bookRecommendations".localized, isOn: .constant(true))
            Toggle("settings.streakReminders".localized, isOn: .constant(true))
        }
        .navigationTitle("settings.notifications".localized)
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        List {
            Section("settings.appTheme".localized) {
                Picker("settings.appearance".localized, selection: $themeManager.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon).tag(mode)
                    }
                }
            }

            Section("settings.readerTheme".localized) {
                Picker("settings.theme".localized, selection: $themeManager.readerTheme) {
                    ForEach(ReaderTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
            }

            Section("settings.fontSize".localized) {
                Picker("settings.size".localized, selection: $themeManager.fontSize) {
                    ForEach(FontSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
            }
        }
        .navigationTitle("settings.appearance".localized)
    }
}

// SubscriptionView replaced by SubscriptionStatusView in Features/Subscriptions/

struct HelpCenterView: View {
    var body: some View {
        List {
            Section("help.faqs".localized) {
                Text("help.faq.addWords".localized)
                Text("help.faq.spacedRepetition".localized)
                Text("help.faq.readOffline".localized)
            }
        }
        .navigationTitle("support.helpCenter".localized)
    }
}

// AboutView moved to Features/About/Views/AboutView.swift
