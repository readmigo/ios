import Foundation
import UIKit

// MARK: - Log Level

enum LogLevel: String, Codable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case fatal = "FATAL"
}

// MARK: - Log Category

enum LogCategory: String, Codable {
    case auth = "Auth"
    case books = "Books"
    case reading = "Reading"
    case ai = "AI"
    case vocabulary = "Vocabulary"
    case learning = "Learning"
    case agora = "Agora"
    case subscription = "Subscription"
    case authorChat = "AuthorChat"
    case cache = "Cache"
    case network = "Network"
    case offline = "Offline"
    case app = "App"
    case localization = "Localization"

    // Enhanced logging categories
    case navigation = "Navigation"     // Page navigation/routing
    case lifecycle = "Lifecycle"       // View lifecycle (appear/disappear)
    case performance = "Performance"   // Performance metrics
    case interaction = "Interaction"   // User interactions
    case sync = "Sync"                 // Data synchronization (Whispersync, etc.)
    case other = "Other"               // Other/miscellaneous
}

// MARK: - Log Entry (Legacy)

struct LogEntry: Codable {
    let level: LogLevel
    let message: String
    let context: [String: String]?
    let timestamp: Date

    init(level: LogLevel, message: String, context: [String: String]? = nil) {
        self.level = level
        self.message = message
        self.context = context
        self.timestamp = Date()
    }
}

// MARK: - Runtime Log Entry

struct RuntimeLogEntry: Codable {
    let level: LogLevel
    let category: LogCategory
    let message: String
    let correlationId: String?
    let sessionId: String?
    let component: String?
    let metadata: [String: String]?
    let timestamp: String  // ISO8601 format

    init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        correlationId: String? = nil,
        sessionId: String? = nil,
        component: String? = nil,
        metadata: [String: String]? = nil
    ) {
        self.level = level
        self.category = category
        self.message = message
        self.correlationId = correlationId
        self.sessionId = sessionId
        self.component = component
        self.metadata = metadata
        self.timestamp = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Runtime Log Batch Request

struct RuntimeLogBatchRequest: Codable {
    let logs: [RuntimeLogEntry]
    let deviceInfo: RuntimeDeviceInfo

    struct RuntimeDeviceInfo: Codable {
        let deviceModel: String
        let osVersion: String
        let appVersion: String
        let buildNumber: String

        static var current: RuntimeDeviceInfo {
            let device = UIDevice.current
            let bundle = Bundle.main

            return RuntimeDeviceInfo(
                deviceModel: device.model,
                osVersion: device.systemVersion,
                appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                buildNumber: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
            )
        }
    }
}

// MARK: - Runtime Log Batch Response

struct RuntimeLogBatchResponse: Codable {
    let received: Int
    let accepted: Int
}

// MARK: - Device Info

struct DeviceInfo: Codable {
    let platform: String
    let osVersion: String
    let appVersion: String
    let appBuild: String
    let deviceModel: String
    let deviceId: String

    static var current: DeviceInfo {
        let device = UIDevice.current
        let bundle = Bundle.main

        return DeviceInfo(
            platform: "ios",
            osVersion: device.systemVersion,
            appVersion: bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            appBuild: bundle.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            deviceModel: device.model,
            deviceId: device.identifierForVendor?.uuidString ?? "unknown"
        )
    }
}

// MARK: - Log Batch Request

struct LogBatchRequest: Codable {
    let logs: [LogEntry]
    let deviceInfo: DeviceInfo
}

// MARK: - Crash Report

struct CrashReport: Codable {
    let errorType: String
    let errorMessage: String
    let stackTrace: String?
    let deviceInfo: DeviceInfo
    let timestamp: Date

    init(errorType: String, errorMessage: String, stackTrace: String? = nil) {
        self.errorType = errorType
        self.errorMessage = errorMessage
        self.stackTrace = stackTrace
        self.deviceInfo = DeviceInfo.current
        self.timestamp = Date()
    }
}

// MARK: - Response Models

struct LogBatchResponse: Codable {
    let success: Bool
    let count: Int?
}

struct CrashReportResponse: Codable {
    let success: Bool
    let reportId: String?
}
