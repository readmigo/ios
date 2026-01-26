import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingFinalDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        List {
            // Account Info Section
            Section("account.info".localized) {
                if let user = authManager.currentUser {
                    HStack {
                        Text("account.email".localized)
                        Spacer()
                        Text(user.email ?? "account.notSet".localized)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("account.memberSince".localized)
                        Spacer()
                        Text(user.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Personal Information
            Section("account.personalInfo".localized) {
                NavigationLink {
                    ProfileEditView()
                } label: {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("account.editProfile".localized)
                    }
                }
            }

            // Connected Accounts
            Section("account.connectedAccounts".localized) {
                HStack {
                    Image(systemName: "apple.logo")
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    Text("Apple")
                    Spacer()
                    if authManager.currentUser?.id.contains("apple") == true {
                        Text("account.connected".localized)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                HStack {
                    Image(systemName: "g.circle.fill")
                        .foregroundColor(.primary)
                        .frame(width: 24)
                    Text("Google")
                    Spacer()
                    if authManager.currentUser?.id.contains("google") == true {
                        Text("account.connected".localized)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }

            // Data & Privacy
            Section("account.dataPrivacy".localized) {
                NavigationLink {
                    DataExportView()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("account.exportData".localized)
                    }
                }

                Link(destination: URL(string: "https://readmigo.app/privacy")!) {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        Text("about.privacyPolicy".localized)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Danger Zone
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .frame(width: 24)
                        Text("account.deleteAccount".localized)
                    }
                }
                .disabled(isDeleting)
            } header: {
                Text("account.dangerZone".localized)
            } footer: {
                Text("account.deleteWarning".localized)
            }
        }
        .navigationTitle("profile.accountSettings".localized)
        .navigationBarTitleDisplayMode(.inline)
        .alert("account.deleteAccount".localized, isPresented: $showingDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("common.continue".localized, role: .destructive) {
                showingFinalDeleteConfirmation = true
            }
        } message: {
            Text("account.deleteConfirmMessage".localized)
        }
        .alert("account.finalConfirmation".localized, isPresented: $showingFinalDeleteConfirmation) {
            Button("common.cancel".localized, role: .cancel) {}
            Button("account.deleteForever".localized, role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("account.finalConfirmMessage".localized)
        }
        .alert("common.error".localized, isPresented: .constant(deleteError != nil)) {
            Button("common.ok".localized) {
                deleteError = nil
            }
        } message: {
            if let error = deleteError {
                Text(error)
            }
        }
        .overlay {
            if isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("account.deleting".localized)
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                try await authManager.deleteAccount()
                dismiss()
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }
}

// MARK: - Data Export View

struct DataExportView: View {
    @State private var isExporting = false
    @State private var exportComplete = false

    var body: some View {
        List {
            Section {
                Text("export.description".localized)
                    .foregroundColor(.secondary)
            }

            Section {
                Label("export.readingHistory".localized, systemImage: "book.closed")
                Label("export.vocabularyList".localized, systemImage: "text.word.spacing")
                Label("export.quotesBookmarks".localized, systemImage: "bookmark")
                Label("export.achievements".localized, systemImage: "chart.bar")
            }

            Section {
                Button {
                    requestExport()
                } label: {
                    HStack {
                        Spacer()
                        if isExporting {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text(isExporting ? "export.preparing".localized : "export.request".localized)
                        Spacer()
                    }
                }
                .disabled(isExporting)
            } footer: {
                Text("export.emailNote".localized)
            }
        }
        .navigationTitle("account.exportData".localized)
        .alert("export.requested".localized, isPresented: $exportComplete) {
            Button("common.ok".localized) {}
        } message: {
            Text("export.emailConfirm".localized)
        }
    }

    private func requestExport() {
        isExporting = true

        // Simulate export request
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            isExporting = false
            exportComplete = true
        }
    }
}

// MARK: - Profile Edit View

// Note: UserProfile, Gender, and UserProfileUpdate are defined in APIClient.swift

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile: UserProfile?
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Form fields
    @State private var selectedGender: Gender?
    @State private var birthYear: String = ""
    @State private var country: String = ""
    @State private var region: String = ""
    @State private var city: String = ""

    var body: some View {
        NavigationView {
            Form {
                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    // Gender Section
                    Section {
                        Picker(selection: $selectedGender) {
                            Text("profile.gender.not_selected".localized).tag(nil as Gender?)
                            ForEach(Gender.allCases.filter { $0 != .unknown }, id: \.self) { gender in
                                Text(gender.displayName).tag(gender as Gender?)
                            }
                        } label: {
                            Text("profile.gender".localized)
                        }
                    } header: {
                        Text("profile.basicInfo".localized)
                    }

                    // Birth Year Section
                    Section {
                        TextField("profile.birthYear.placeholder".localized, text: $birthYear)
                            .keyboardType(.numberPad)
                    } footer: {
                        Text("profile.birthYear.hint".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Location Section
                    Section {
                        TextField("profile.country".localized, text: $country)
                        TextField("profile.region".localized, text: $region)
                        TextField("profile.city".localized, text: $city)
                    } header: {
                        Text("profile.location".localized)
                    } footer: {
                        Text("profile.location.hint".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Error Message
                    if let errorMessage = errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("profile.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isSaving || isLoading)
                }
            }
            .task {
                await loadProfile()
            }
        }
    }

    private func loadProfile() async {
        isLoading = true
        errorMessage = nil

        do {
            let loadedProfile = try await APIClient.shared.getUserProfile()
            profile = loadedProfile

            // Populate form fields
            selectedGender = loadedProfile.gender
            birthYear = loadedProfile.birthYear.map { String($0) } ?? ""
            country = loadedProfile.country ?? ""
            region = loadedProfile.region ?? ""
            city = loadedProfile.city ?? ""
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func saveProfile() async {
        isSaving = true
        errorMessage = nil

        // Validate birth year
        var validatedBirthYear: Int?
        if !birthYear.isEmpty {
            if let year = Int(birthYear), year >= 1900 && year <= Calendar.current.component(.year, from: Date()) {
                validatedBirthYear = year
            } else {
                errorMessage = "profile.error.invalidBirthYear".localized
                isSaving = false
                return
            }
        }

        do {
            let update = UserProfileUpdate(
                gender: selectedGender,
                birthYear: validatedBirthYear,
                country: country.isEmpty ? nil : country,
                region: region.isEmpty ? nil : region,
                city: city.isEmpty ? nil : city
            )

            let updatedProfile = try await APIClient.shared.updateUserProfile(update)
            profile = updatedProfile

            // Success - dismiss view
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
