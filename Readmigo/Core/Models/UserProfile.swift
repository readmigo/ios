import Foundation

/// User profile information
struct UserProfile: Codable, Identifiable {
    let id: String
    let userId: String
    var gender: Gender?
    var birthYear: Int?
    var country: String?
    var region: String?
    var city: String?
    var timezone: String?
    let createdAt: Date
    let updatedAt: Date
}

/// Gender enum matching backend
enum Gender: String, Codable, CaseIterable {
    case male = "MALE"
    case female = "FEMALE"
    case other = "OTHER"
    case preferNotToSay = "PREFER_NOT_TO_SAY"
    case unknown = "UNKNOWN"

    var displayName: String {
        switch self {
        case .male:
            return NSLocalizedString("profile.gender.male", value: "Male", comment: "")
        case .female:
            return NSLocalizedString("profile.gender.female", value: "Female", comment: "")
        case .other:
            return NSLocalizedString("profile.gender.other", value: "Other", comment: "")
        case .preferNotToSay:
            return NSLocalizedString("profile.gender.prefer_not_to_say", value: "Prefer not to say", comment: "")
        case .unknown:
            return NSLocalizedString("profile.gender.unknown", value: "Unknown", comment: "")
        }
    }
}

/// User profile update request
struct UserProfileUpdate: Codable {
    var gender: Gender?
    var birthYear: Int?
    var country: String?
    var region: String?
    var city: String?
}
