import Foundation
import UIKit
#if canImport(Sentry)
import Sentry
#endif

/// Crash tracking service that provides full-stack error reporting
/// Supports integration with Sentry, Firebase Crashlytics, or custom backend
///
/// ## Setup Instructions
/// 1. In Xcode, go to File > Add Package Dependencies
/// 2. Enter: https://github.com/getsentry/sentry-cocoa
/// 3. Select version 8.0.0 or later
/// 4. Add to your target
/// 5. Get your DSN from https://sentry.io (free tier: 5K errors/month)
/// 6. Call initializeSentry(dsn:) in your App init
@MainActor
class CrashTrackingService: ObservableObject {
    static let shared = CrashTrackingService()

    enum Provider {
        case sentry
        case firebase
        case custom
    }

    private var isInitialized = false
    private var provider: Provider = .custom

    private init() {}

    // MARK: - Initialization

    /// Initialize crash tracking with Sentry
    /// Call this in AppDelegate or App init
    func initializeSentry(dsn: String) {
        #if canImport(Sentry)
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false

            // Performance monitoring (20% sampling for free tier efficiency)
            options.tracesSampleRate = 0.2
            options.profilesSampleRate = 0.1

            // Crash context
            options.attachScreenshot = true
            options.attachViewHierarchy = true

            // Session tracking
            options.enableAutoSessionTracking = true
            options.sessionTrackingIntervalMillis = 30000

            // Network tracking
            options.enableCaptureFailedRequests = true
            options.enableNetworkTracking = true
            options.enableNetworkBreadcrumbs = true

            // App hang detection
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2

            // Breadcrumbs
            options.maxBreadcrumbs = 100
            options.enableAutoBreadcrumbTracking = true

            // Environment
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif

            // Release version
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "com.readmigo.ios@\(version)+\(build)"
            }

            // Filter PII before sending
            options.beforeSend = { event in
                // Remove email from user data for privacy
                if var user = event.user {
                    user.email = nil
                    event.user = user
                }
                return event
            }
        }

        provider = .sentry
        isInitialized = true
        LoggingService.shared.info("Sentry crash tracking initialized")

        // Also initialize custom backend as backup
        setupSignalHandlers()
        checkForPreviousCrash()
        #else
        // Fallback to custom backend when SDK is not available
        LoggingService.shared.warning("Sentry SDK not integrated, using custom backend. Add Sentry SDK via SPM to enable.")
        initializeCustomBackend()
        #endif
    }

    /// Initialize crash tracking with Firebase Crashlytics
    ///
    /// To use Firebase:
    /// 1. Add Firebase SDK via Swift Package Manager
    /// 2. Add GoogleService-Info.plist to your project
    /// 3. Initialize Firebase in AppDelegate
    /// 4. Call: CrashTrackingService.shared.initializeFirebase()
    func initializeFirebase() {
        // Note: Uncomment below when Firebase SDK is added
        /*
        import FirebaseCrashlytics

        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
        provider = .firebase
        isInitialized = true
        */

        LoggingService.shared.warning("Firebase SDK not integrated, using custom backend. Add Firebase SDK to enable.")
        initializeCustomBackend()
    }

    /// Initialize with custom backend (existing LoggingService)
    func initializeCustomBackend() {
        provider = .custom
        isInitialized = true

        // Setup uncaught exception handler
        NSSetUncaughtExceptionHandler { exception in
            Task { @MainActor in
                CrashTrackingService.shared.reportException(exception)
            }
        }

        // Setup signal handlers for crashes
        setupSignalHandlers()

        // Check for pending crash from previous session
        checkForPreviousCrash()

        LoggingService.shared.info("Custom crash tracking initialized")
    }

    // MARK: - Error Reporting

    /// Report a non-fatal error
    func reportError(_ error: Error, context: [String: Any]? = nil) {
        let errorInfo = buildErrorInfo(error: error, context: context)

        switch provider {
        case .sentry:
            reportToSentry(error: error, context: context)
        case .firebase:
            reportToFirebase(error: error, context: context)
        case .custom:
            reportToCustomBackend(errorInfo: errorInfo)
        }

        // Also add breadcrumb
        addBreadcrumb(
            category: "error",
            message: error.localizedDescription,
            level: .error,
            data: context
        )
    }

    /// Report an exception
    func reportException(_ exception: NSException) {
        let errorInfo: [String: Any] = [
            "type": "exception",
            "name": exception.name.rawValue,
            "reason": exception.reason ?? "Unknown",
            "callStack": exception.callStackSymbols.joined(separator: "\n"),
            "userInfo": exception.userInfo ?? [:],
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        switch provider {
        case .sentry, .firebase:
            // SDK handles this automatically when integrated
            break
        case .custom:
            reportToCustomBackend(errorInfo: errorInfo)
        }

        // Save crash info for next launch
        saveCrashInfo(errorInfo)
    }

    /// Report a custom message with context
    func reportMessage(_ message: String, level: LogLevel = .error, context: [String: Any]? = nil) {
        var errorInfo: [String: Any] = [
            "type": "message",
            "message": message,
            "level": level.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let context = context {
            errorInfo["context"] = context
        }

        switch provider {
        case .sentry, .firebase:
            // SDK handles this when integrated
            break
        case .custom:
            reportToCustomBackend(errorInfo: errorInfo)
        }
    }

    // MARK: - User Identification

    /// Set user information for crash reports
    func setUser(id: String, email: String? = nil, username: String? = nil) {
        UserDefaults.standard.set(id, forKey: "crashTracking.userId")
        if let email = email {
            UserDefaults.standard.set(email, forKey: "crashTracking.userEmail")
        }
        if let username = username {
            UserDefaults.standard.set(username, forKey: "crashTracking.username")
        }

        #if canImport(Sentry)
        let sentryUser = Sentry.User()
        sentryUser.userId = id
        // Note: We don't set email for privacy (filtered in beforeSend anyway)
        sentryUser.username = username
        SentrySDK.setUser(sentryUser)
        #endif
    }

    /// Clear user information
    func clearUser() {
        UserDefaults.standard.removeObject(forKey: "crashTracking.userId")
        UserDefaults.standard.removeObject(forKey: "crashTracking.userEmail")
        UserDefaults.standard.removeObject(forKey: "crashTracking.username")

        #if canImport(Sentry)
        SentrySDK.setUser(nil)
        #endif
    }

    // MARK: - Breadcrumbs

    private var breadcrumbs: [[String: Any]] = []
    private let maxBreadcrumbs = 100

    /// Add a breadcrumb for debugging
    func addBreadcrumb(category: String, message: String, level: LogLevel = .info, data: [String: Any]? = nil) {
        var crumb: [String: Any] = [
            "category": category,
            "message": message,
            "level": level.rawValue,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = data {
            crumb["data"] = data
        }

        breadcrumbs.append(crumb)
        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst()
        }

        // Also log via logging service
        LoggingService.shared.info("[\(category)] \(message)", context: data?.mapValues { String(describing: $0) })
    }

    // MARK: - Context

    private var customContext: [String: [String: Any]] = [:]

    /// Set custom context for crash reports
    func setContext(key: String, value: [String: Any]) {
        customContext[key] = value

        // Persist for crash reports
        if let data = try? JSONSerialization.data(withJSONObject: value) {
            UserDefaults.standard.set(data, forKey: "crashTracking.context.\(key)")
        }
    }

    /// Clear custom context
    func clearContext(key: String) {
        customContext.removeValue(forKey: key)
        UserDefaults.standard.removeObject(forKey: "crashTracking.context.\(key)")
    }

    // MARK: - Private Methods

    private func buildErrorInfo(error: Error, context: [String: Any]?) -> [String: Any] {
        var info: [String: Any] = [
            "type": "error",
            "errorType": String(describing: type(of: error)),
            "errorMessage": error.localizedDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "deviceInfo": [
                "platform": DeviceInfo.current.platform,
                "osVersion": DeviceInfo.current.osVersion,
                "appVersion": DeviceInfo.current.appVersion,
                "appBuild": DeviceInfo.current.appBuild,
                "deviceModel": DeviceInfo.current.deviceModel
            ],
            "breadcrumbs": breadcrumbs.suffix(20) // Last 20 breadcrumbs
        ]

        if let context = context {
            info["context"] = context
        }

        // Add user info if available
        if let userId = UserDefaults.standard.string(forKey: "crashTracking.userId") {
            info["userId"] = userId
        }

        // Add custom context
        if !customContext.isEmpty {
            info["customContext"] = customContext
        }

        return info
    }

    private func reportToSentry(error: Error, context: [String: Any]?) {
        #if canImport(Sentry)
        SentrySDK.capture(error: error) { scope in
            if let context = context {
                scope.setContext(value: context.mapValues { "\($0)" }, key: "custom")
            }
            // Add recent breadcrumbs
            for crumb in self.breadcrumbs.suffix(20) {
                let breadcrumb = Breadcrumb()
                breadcrumb.category = crumb["category"] as? String ?? "unknown"
                breadcrumb.message = crumb["message"] as? String ?? ""
                breadcrumb.level = self.mapLogLevelToSentry(crumb["level"] as? String)
                if let timestamp = crumb["timestamp"] as? String {
                    let formatter = ISO8601DateFormatter()
                    breadcrumb.timestamp = formatter.date(from: timestamp)
                }
                scope.addBreadcrumb(breadcrumb)
            }
        }
        #endif
    }

    #if canImport(Sentry)
    private func mapLogLevelToSentry(_ level: String?) -> SentryLevel {
        switch level {
        case "debug": return .debug
        case "info": return .info
        case "warning": return .warning
        case "error": return .error
        case "fatal": return .fatal
        default: return .info
        }
    }
    #endif

    private func reportToFirebase(error: Error, context: [String: Any]?) {
        // Implemented when Firebase SDK is added
    }

    private func reportToCustomBackend(errorInfo: [String: Any]) {
        Task {
            await LoggingService.shared.reportCrash(
                errorType: errorInfo["errorType"] as? String ?? "Unknown",
                errorMessage: errorInfo["errorMessage"] as? String ?? "Unknown error",
                stackTrace: errorInfo["callStack"] as? String
            )
        }
    }

    private func setupSignalHandlers() {
        // Setup signal handlers for SIGABRT, SIGSEGV, etc.
        signal(SIGABRT) { signal in
            let message = "Signal SIGABRT (\(signal)) received"
            UserDefaults.standard.set(message, forKey: "crashTracking.lastSignal")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "crashTracking.lastCrashTime")
        }

        signal(SIGSEGV) { signal in
            let message = "Signal SIGSEGV (\(signal)) received"
            UserDefaults.standard.set(message, forKey: "crashTracking.lastSignal")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "crashTracking.lastCrashTime")
        }

        signal(SIGBUS) { signal in
            let message = "Signal SIGBUS (\(signal)) received"
            UserDefaults.standard.set(message, forKey: "crashTracking.lastSignal")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "crashTracking.lastCrashTime")
        }

        signal(SIGFPE) { signal in
            let message = "Signal SIGFPE (\(signal)) received"
            UserDefaults.standard.set(message, forKey: "crashTracking.lastSignal")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "crashTracking.lastCrashTime")
        }
    }

    private func saveCrashInfo(_ info: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: info) {
            UserDefaults.standard.set(data, forKey: "crashTracking.lastCrashInfo")
        }
    }

    private func checkForPreviousCrash() {
        // Check for signal crash
        if let signalMessage = UserDefaults.standard.string(forKey: "crashTracking.lastSignal") {
            let crashTime = UserDefaults.standard.double(forKey: "crashTracking.lastCrashTime")

            Task {
                await LoggingService.shared.reportCrash(
                    errorType: "SignalCrash",
                    errorMessage: signalMessage,
                    stackTrace: "Crash occurred at: \(Date(timeIntervalSince1970: crashTime))"
                )
            }

            UserDefaults.standard.removeObject(forKey: "crashTracking.lastSignal")
            UserDefaults.standard.removeObject(forKey: "crashTracking.lastCrashTime")
        }

        // Check for exception crash
        if let crashData = UserDefaults.standard.data(forKey: "crashTracking.lastCrashInfo"),
           let crashInfo = try? JSONSerialization.jsonObject(with: crashData) as? [String: Any] {

            Task {
                await LoggingService.shared.reportCrash(
                    errorType: crashInfo["name"] as? String ?? "Exception",
                    errorMessage: crashInfo["reason"] as? String ?? "Unknown",
                    stackTrace: crashInfo["callStack"] as? String
                )
            }

            UserDefaults.standard.removeObject(forKey: "crashTracking.lastCrashInfo")
        }

        // Retry any pending crash reports
        Task {
            await LoggingService.shared.retrySavedCrashReport()
        }
    }
}

// MARK: - Convenience Extensions

extension CrashTrackingService {
    /// Track screen views for breadcrumb trail
    func trackScreenView(_ screenName: String) {
        addBreadcrumb(
            category: "navigation",
            message: "Viewed \(screenName)",
            level: .info
        )
    }

    /// Track user actions for breadcrumb trail
    func trackAction(_ action: String, target: String? = nil) {
        var message = action
        if let target = target {
            message += " on \(target)"
        }
        addBreadcrumb(
            category: "user",
            message: message,
            level: .info
        )
    }

    /// Track network requests for debugging
    func trackNetworkRequest(url: String, method: String, statusCode: Int?, error: Error?) {
        var data: [String: Any] = [
            "url": url,
            "method": method
        ]
        if let statusCode = statusCode {
            data["statusCode"] = statusCode
        }

        let level: LogLevel = error != nil || (statusCode ?? 200) >= 400 ? .error : .info

        addBreadcrumb(
            category: "network",
            message: "\(method) \(url)",
            level: level,
            data: data
        )

        if let error = error {
            reportError(error, context: data)
        }
    }
}
