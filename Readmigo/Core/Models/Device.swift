import Foundation
import UIKit

// MARK: - Platform

enum DevicePlatform: String, Codable, CaseIterable {
    case ios = "IOS"
    case android = "ANDROID"
    case web = "WEB"

    var displayName: String {
        switch self {
        case .ios: return "iOS"
        case .android: return "Android"
        case .web: return "Web"
        }
    }

    var icon: String {
        switch self {
        case .ios: return "iphone"
        case .android: return "smartphone"
        case .web: return "globe"
        }
    }
}

// MARK: - Device Model

struct Device: Codable, Identifiable, Hashable {
    let id: String
    let deviceId: String
    let userId: String?
    let platform: DevicePlatform
    let deviceModel: String?
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let isCurrent: Bool
    let isPrimary: Bool
    let isLoggedOut: Bool
    let lastActiveAt: Date
    let createdAt: Date

    /// Display name for the device (custom name > model > generic)
    var displayName: String {
        if let name = deviceName, !name.isEmpty {
            return name
        }
        if let model = deviceModel, !model.isEmpty {
            return model
        }
        return "\(platform.displayName) Device"
    }

    /// Formatted last active time
    var lastActiveFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastActiveAt, relativeTo: Date())
    }

    /// Whether this device was active recently (within 5 minutes)
    var isActiveNow: Bool {
        lastActiveAt.timeIntervalSinceNow > -300
    }
}

// MARK: - Device List Response

struct DeviceListResponse: Codable {
    let devices: [Device]
    let totalDevices: Int
    let maxDevices: Int
    let canAddMore: Bool
}

// MARK: - Device Stats

struct DeviceStats: Codable {
    let totalDevices: Int
    let byPlatform: [String: Int]
    let lastActiveDeviceId: String?
    let primaryDeviceId: String?
}

// MARK: - Register Device Request

struct RegisterDeviceRequest: Codable {
    let deviceId: String
    let platform: DevicePlatform
    let deviceModel: String?
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let pushToken: String?

    /// Create a request for the current device
    static func current(pushToken: String? = nil) -> RegisterDeviceRequest {
        let deviceInfo = AboutDeviceInfo.current
        let bundle = Bundle.main

        return RegisterDeviceRequest(
            deviceId: UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString,
            platform: .ios,
            deviceModel: deviceInfo.model,
            deviceName: UIDevice.current.name,
            osVersion: deviceInfo.systemVersion,
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
            pushToken: pushToken
        )
    }
}

// MARK: - Register Device Response

struct RegisterDeviceResponse: Codable {
    let device: Device
    let isNew: Bool
    let loginAllowed: Bool
    let message: String?
}

// MARK: - Update Device Request

struct UpdateDeviceRequest: Codable {
    let deviceName: String?
    let osVersion: String?
    let appVersion: String?
    let pushToken: String?
    let isPrimary: Bool?

    init(
        deviceName: String? = nil,
        osVersion: String? = nil,
        appVersion: String? = nil,
        pushToken: String? = nil,
        isPrimary: Bool? = nil
    ) {
        self.deviceName = deviceName
        self.osVersion = osVersion
        self.appVersion = appVersion
        self.pushToken = pushToken
        self.isPrimary = isPrimary
    }
}

// MARK: - Logout Response

struct DeviceLogoutResponse: Codable {
    let success: Bool
    let message: String
}

// MARK: - Check Logout Response

struct CheckLogoutResponse: Codable {
    let isLoggedOut: Bool
}
