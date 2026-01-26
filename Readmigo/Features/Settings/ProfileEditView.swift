import SwiftUI

// Note: UserProfile, Gender, and UserProfileUpdate are now defined in APIClient.swift

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

// MARK: - Localization Keys
extension String {
    static let profileGenderNotSelected = "profile.gender.not_selected"
    static let profileGender = "profile.gender"
    static let profileBasicInfo = "profile.basicInfo"
    static let profileBirthYearPlaceholder = "profile.birthYear.placeholder"
    static let profileBirthYearHint = "profile.birthYear.hint"
    static let profileCountry = "profile.country"
    static let profileRegion = "profile.region"
    static let profileCity = "profile.city"
    static let profileLocation = "profile.location"
    static let profileLocationHint = "profile.location.hint"
    static let profileEdit = "profile.edit"
    static let profileErrorInvalidBirthYear = "profile.error.invalidBirthYear"
}
