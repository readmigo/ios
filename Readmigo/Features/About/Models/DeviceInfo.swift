import UIKit

/// Device information model for About screen
struct AboutDeviceInfo {
    /// Device model name (e.g., "iPhone 15 Pro")
    let model: String
    /// System version (e.g., "iOS 17.0")
    let systemVersion: String
    /// Current language code (e.g., "en", "zh-Hans")
    let language: String

    /// Get current device information
    static var current: AboutDeviceInfo {
        AboutDeviceInfo(
            model: UIDevice.current.modelName,
            systemVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            language: Locale.current.language.languageCode?.identifier ?? "Unknown"
        )
    }
}

// MARK: - UIDevice Extension for Model Name

extension UIDevice {
    /// Get human-readable device model name
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return mapToDevice(identifier: identifier)
    }

    private func mapToDevice(identifier: String) -> String {
        switch identifier {
        // iPhone 16 Series
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        // iPhone 15 Series
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        // iPhone 14 Series
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        // iPhone 13 Series
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        // iPhone 12 Series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        // iPhone 11 Series
        case "iPhone12,1": return "iPhone 11"
        case "iPhone12,3": return "iPhone 11 Pro"
        case "iPhone12,5": return "iPhone 11 Pro Max"
        // iPhone SE Series
        case "iPhone14,6": return "iPhone SE (3rd generation)"
        case "iPhone12,8": return "iPhone SE (2nd generation)"
        // iPad Series (common ones)
        case "iPad13,18", "iPad13,19": return "iPad (10th generation)"
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch (4th generation)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch (6th generation)"
        case "iPad14,1", "iPad14,2": return "iPad mini (6th generation)"
        case "iPad13,16", "iPad13,17": return "iPad Air (5th generation)"
        // Simulator
        case "i386", "x86_64", "arm64":
            return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
        default:
            return identifier
        }
    }
}
