import Foundation
import UIKit
import os.log

@MainActor
class LoggingService: ObservableObject {
    static let shared = LoggingService()

    private let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.readmigo", category: "app")
    private var logQueue: [LogEntry] = []
    private var runtimeLogQueue: [RuntimeLogEntry] = []
    private var flushTimer: Timer?

    private let maxQueueSize = 100
    private let flushInterval: TimeInterval = 60

    private let userDefaultsKey = "pendingLogs"
    private let runtimeLogsKey = "pendingRuntimeLogs"

    /// Current correlation ID for request tracing
    private(set) var currentCorrelationId: String?

    /// Current session ID
    private(set) var sessionId: String = UUID().uuidString

    private init() {
        loadPendingLogs()
        loadPendingRuntimeLogs()
        startFlushTimer()
        setupAppLifecycleObservers()
    }

    // MARK: - Correlation ID Management

    /// Generate a new correlation ID for request tracing
    func generateCorrelationId() -> String {
        let id = UUID().uuidString
        currentCorrelationId = id
        return id
    }

    /// Clear the current correlation ID
    func clearCorrelationId() {
        currentCorrelationId = nil
    }

    /// Reset session ID (e.g., on new app launch)
    func resetSessionId() {
        sessionId = UUID().uuidString
    }

    // MARK: - Debug File Logging

    private static let debugLogFileName = "ReaderDebug.log"

    /// Write debug message to file for easier debugging on device
    static func writeDebugLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logLine = "[\(timestamp)] \(message)\n"

        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("📖 [DebugLog] Failed to get documents directory")
            return
        }

        let fileURL = documentsDirectory.appendingPathComponent(debugLogFileName)

        // Create file if it doesn't exist
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }

        // Append to file
        if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            if let data = logLine.data(using: .utf8) {
                fileHandle.write(data)
            }
            fileHandle.closeFile()
        }
    }

    /// Clear the debug log file
    static func clearDebugLog() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = documentsDirectory.appendingPathComponent(debugLogFileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Get the debug log file URL for sharing
    static func getDebugLogURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return documentsDirectory.appendingPathComponent(debugLogFileName)
    }

    // MARK: - Public Logging Methods (Legacy)

    func debug(_ message: String, context: [String: String]? = nil) {
        log(.debug, message: message, context: context)
    }

    func info(_ message: String, context: [String: String]? = nil) {
        log(.info, message: message, context: context)
    }

    func warning(_ message: String, context: [String: String]? = nil) {
        log(.warning, message: message, context: context)
    }

    func error(_ message: String, context: [String: String]? = nil) {
        log(.error, message: message, context: context)
    }

    func fatal(_ message: String, context: [String: String]? = nil) {
        log(.fatal, message: message, context: context)
    }

    // MARK: - Category-Based Logging

    /// Log a debug message with category
    func debug(_ category: LogCategory, _ message: String, component: String? = nil, metadata: [String: String]? = nil) {
        logRuntime(.debug, category: category, message: message, component: component, metadata: metadata)
    }

    /// Log an info message with category
    func info(_ category: LogCategory, _ message: String, component: String? = nil, metadata: [String: String]? = nil) {
        logRuntime(.info, category: category, message: message, component: component, metadata: metadata)
    }

    /// Log a warning message with category
    func warning(_ category: LogCategory, _ message: String, component: String? = nil, metadata: [String: String]? = nil) {
        logRuntime(.warning, category: category, message: message, component: component, metadata: metadata)
    }

    /// Log an error message with category
    func error(_ category: LogCategory, _ message: String, component: String? = nil, metadata: [String: String]? = nil) {
        logRuntime(.error, category: category, message: message, component: component, metadata: metadata)
    }

    /// Log a fatal message with category
    func fatal(_ category: LogCategory, _ message: String, component: String? = nil, metadata: [String: String]? = nil) {
        logRuntime(.fatal, category: category, message: message, component: component, metadata: metadata)
    }

    func logRuntime(
        _ level: LogLevel,
        category: LogCategory,
        message: String,
        component: String?,
        metadata: [String: String]?
    ) {
        let entry = RuntimeLogEntry(
            level: level,
            category: category,
            message: "[\(category.rawValue)] \(message)",
            correlationId: currentCorrelationId,
            sessionId: sessionId,
            component: component,
            metadata: metadata
        )

        runtimeLogQueue.append(entry)

        // Also log to system log with unified format for easy filtering
        let osLogType: OSLogType = {
            switch level {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .fatal: return .fault
            }
        }()

        // Format: [Readmigo][Category][Level] message
        // Can filter in Console.app using: [Readmigo] or [Readmigo][Books] etc.
        let levelEmoji: String = {
            switch level {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .fatal: return "💀"
            }
        }()
        let formattedMessage = "[Readmigo][\(category.rawValue)][\(level.rawValue)] \(levelEmoji) \(message)"
        os_log("%{public}@", log: osLog, type: osLogType, formattedMessage as NSString)

        if runtimeLogQueue.count >= maxQueueSize {
            Task { await flushRuntimeLogs() }
        }
    }

    // MARK: - Crash Reporting

    func reportCrash(errorType: String, errorMessage: String, stackTrace: String? = nil) async {
        let report = CrashReport(
            errorType: errorType,
            errorMessage: errorMessage,
            stackTrace: stackTrace
        )

        do {
            let _: CrashReportResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.logsCrash,
                method: .post,
                body: report
            )
        } catch {
            os_log(.error, log: osLog, "Failed to send crash report: %{public}@", error.localizedDescription)
            // Store locally for later retry
            saveCrashReportLocally(report)
        }
    }

    // MARK: - Private Methods

    private func log(_ level: LogLevel, message: String, context: [String: String]?) {
        let entry = LogEntry(level: level, message: message, context: context)
        logQueue.append(entry)

        // Also log to system log with unified format
        let osLogType: OSLogType = {
            switch level {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .fatal: return .fault
            }
        }()

        let levelEmoji: String = {
            switch level {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .fatal: return "💀"
            }
        }()
        let formattedMessage = "[Readmigo][App][\(level.rawValue)] \(levelEmoji) \(message)"
        os_log(osLogType, log: osLog, "%{public}@", formattedMessage)

        if logQueue.count >= maxQueueSize {
            Task { await flush() }
        }
    }

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.flush()
            }
        }
    }

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.savePendingLogs()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.savePendingLogs()
        }
    }

    func flush() async {
        // Flush legacy logs
        await flushLegacyLogs()
        // Flush runtime logs
        await flushRuntimeLogs()
    }

    private func flushLegacyLogs() async {
        guard !logQueue.isEmpty else { return }

        // Skip log upload in guest mode (not authenticated)
        guard AuthManager.shared.isAuthenticated else {
            // Clear queue to prevent accumulation in guest mode
            logQueue.removeAll()
            return
        }

        let logsToSend = logQueue
        logQueue.removeAll()

        let request = LogBatchRequest(
            logs: logsToSend,
            deviceInfo: DeviceInfo.current
        )

        do {
            let _: LogBatchResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.logsBatch,
                method: .post,
                body: request
            )
        } catch {
            os_log(.error, log: osLog, "Failed to flush logs: %{public}@", error.localizedDescription)
            // Put logs back in queue
            logQueue.insert(contentsOf: logsToSend, at: 0)
            // Trim if too large
            if logQueue.count > maxQueueSize * 2 {
                logQueue = Array(logQueue.suffix(maxQueueSize))
            }
        }
    }

    private func flushRuntimeLogs() async {
        guard !runtimeLogQueue.isEmpty else { return }

        // Skip runtime log upload in guest mode (not authenticated)
        guard AuthManager.shared.isAuthenticated else {
            // Clear queue to prevent accumulation in guest mode
            runtimeLogQueue.removeAll()
            return
        }

        let logsToSend = runtimeLogQueue
        runtimeLogQueue.removeAll()

        let request = RuntimeLogBatchRequest(
            logs: logsToSend,
            deviceInfo: RuntimeLogBatchRequest.RuntimeDeviceInfo.current
        )

        do {
            let _: RuntimeLogBatchResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.runtimeLogsBatch,
                method: .post,
                body: request
            )
        } catch {
            os_log(.error, log: osLog, "Failed to flush runtime logs: %{public}@", error.localizedDescription)
            // Put logs back in queue
            runtimeLogQueue.insert(contentsOf: logsToSend, at: 0)
            // Trim if too large
            if runtimeLogQueue.count > maxQueueSize * 2 {
                runtimeLogQueue = Array(runtimeLogQueue.suffix(maxQueueSize))
            }
        }
    }

    // MARK: - Persistence

    private func savePendingLogs() {
        // Save legacy logs
        if !logQueue.isEmpty {
            do {
                let data = try JSONEncoder().encode(logQueue)
                UserDefaults.standard.set(data, forKey: userDefaultsKey)
            } catch {
                os_log(.error, log: osLog, "Failed to save pending logs: %{public}@", error.localizedDescription)
            }
        }

        // Save runtime logs
        if !runtimeLogQueue.isEmpty {
            do {
                let data = try JSONEncoder().encode(runtimeLogQueue)
                UserDefaults.standard.set(data, forKey: runtimeLogsKey)
            } catch {
                os_log(.error, log: osLog, "Failed to save pending runtime logs: %{public}@", error.localizedDescription)
            }
        }
    }

    private func loadPendingLogs() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return }

        do {
            let logs = try JSONDecoder().decode([LogEntry].self, from: data)
            logQueue.append(contentsOf: logs)
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        } catch {
            os_log(.error, log: osLog, "Failed to load pending logs: %{public}@", error.localizedDescription)
        }
    }

    private func loadPendingRuntimeLogs() {
        guard let data = UserDefaults.standard.data(forKey: runtimeLogsKey) else { return }

        do {
            let logs = try JSONDecoder().decode([RuntimeLogEntry].self, from: data)
            runtimeLogQueue.append(contentsOf: logs)
            UserDefaults.standard.removeObject(forKey: runtimeLogsKey)
        } catch {
            os_log(.error, log: osLog, "Failed to load pending runtime logs: %{public}@", error.localizedDescription)
        }
    }

    private func saveCrashReportLocally(_ report: CrashReport) {
        let key = "pendingCrashReport"
        do {
            let data = try JSONEncoder().encode(report)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            os_log(.error, log: osLog, "Failed to save crash report: %{public}@", error.localizedDescription)
        }
    }

    func retrySavedCrashReport() async {
        let key = "pendingCrashReport"
        guard let data = UserDefaults.standard.data(forKey: key) else { return }

        do {
            let report = try JSONDecoder().decode(CrashReport.self, from: data)
            let _: CrashReportResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.logsCrash,
                method: .post,
                body: report
            )
            UserDefaults.standard.removeObject(forKey: key)
        } catch {
            os_log(.error, log: osLog, "Failed to retry crash report: %{public}@", error.localizedDescription)
        }
    }
}
