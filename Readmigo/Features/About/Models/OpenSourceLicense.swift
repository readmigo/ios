import Foundation

/// License types for open source libraries
enum LicenseType: String {
    case mit = "MIT License"
    case apache2 = "Apache License 2.0"
    case bsd3 = "BSD 3-Clause License"
    case gpl3 = "GPL v3"
    case custom = "Custom License"
}

/// Open source library license information
struct OpenSourceLicense: Identifiable {
    let id = UUID()
    /// Library name
    let name: String
    /// Library version
    let version: String?
    /// License type
    let license: LicenseType
    /// Project URL
    let url: URL?
    /// Full license text
    let licenseText: String
}
