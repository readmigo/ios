import Foundation
import os.log

// MARK: - Page Lifecycle Logging

extension LoggingService {

    // MARK: - Page Enter/Exit

    /// Log when a page is entered
    func pageEnter(
        _ pageName: String,
        source: String? = nil,
        metadata: [String: String] = [:]
    ) {
        let tracker = NavigationTracker.shared
        tracker.pushPage(pageName, source: source, metadata: metadata)

        #if DEBUG
        printFormattedPageEnter(pageName, source: source, metadata: metadata)
        #endif

        var fullMetadata = metadata
        fullMetadata["source"] = source ?? "unknown"
        fullMetadata["breadcrumb"] = tracker.breadcrumb
        fullMetadata["sessionFlow"] = String(tracker.sessionFlowId.prefix(8))

        logRuntime(.info, category: .lifecycle,
                   message: "Page Enter: \(pageName)",
                   component: pageName,
                   metadata: fullMetadata)
    }

    /// Log when a page is exited
    func pageExit(_ pageName: String) {
        let tracker = NavigationTracker.shared
        let duration = tracker.popPage(pageName)

        #if DEBUG
        printFormattedPageExit(pageName, duration: duration)
        #endif

        var metadata: [String: String] = [:]
        if let d = duration {
            metadata["duration_ms"] = String(format: "%.0f", d * 1000)
            metadata["duration_s"] = String(format: "%.2f", d)
        }

        logRuntime(.info, category: .lifecycle,
                   message: "Page Exit: \(pageName)",
                   component: pageName,
                   metadata: metadata)
    }

    // MARK: - Performance Logging

    /// Log performance metrics for a page
    func pagePerformance(
        _ pageName: String,
        initToRender: TimeInterval,
        memoryMB: Double? = nil
    ) {
        #if DEBUG
        printFormattedPerformance(pageName, initToRender: initToRender, memoryMB: memoryMB)
        #endif

        var metadata: [String: String] = [
            "init_to_render_ms": String(format: "%.0f", initToRender * 1000)
        ]
        if let memory = memoryMB {
            metadata["memory_mb"] = String(format: "%.1f", memory)
        }

        logRuntime(.debug, category: .performance,
                   message: "Render: \(pageName) in \(String(format: "%.3f", initToRender))s",
                   component: pageName,
                   metadata: metadata)
    }

    // MARK: - User Interaction Logging

    /// Log user interaction events
    func userAction(
        _ action: String,
        target: String,
        page: String,
        metadata: [String: String] = [:]
    ) {
        #if DEBUG
        printFormattedUserAction(action, target: target, page: page)
        #endif

        var fullMetadata = metadata
        fullMetadata["action"] = action
        fullMetadata["target"] = target

        logRuntime(.info, category: .interaction,
                   message: "Action: \(action) on \(target)",
                   component: page,
                   metadata: fullMetadata)
    }

    // MARK: - App Lifecycle Logging

    /// Log app launch
    func appLaunch() {
        let deviceInfo = RuntimeLogBatchRequest.RuntimeDeviceInfo.current

        #if DEBUG
        printFormattedAppLaunch(deviceInfo: deviceInfo)
        #endif

        let tracker = NavigationTracker.shared

        logRuntime(.info, category: .app,
                   message: "Application Launch",
                   component: "App",
                   metadata: [
                       "version": deviceInfo.appVersion,
                       "build": deviceInfo.buildNumber,
                       "device": deviceInfo.deviceModel,
                       "os": deviceInfo.osVersion,
                       "sessionId": tracker.sessionFlowId
                   ])
    }
}

// MARK: - Debug Formatters

#if DEBUG
extension LoggingService {

    func printFormattedPageEnter(
        _ pageName: String,
        source: String?,
        metadata: [String: String]
    ) {
        let separator = String(repeating: "═", count: 64)
        let timestamp = formatTimestamp(Date())
        let tracker = NavigationTracker.shared
        var lines: [String] = []

        lines.append(separator)
        lines.append("[Lifecycle] ▶️ PAGE ENTER: \(pageName)")
        lines.append("├─ Timestamp: \(timestamp)")
        lines.append("├─ Source: \(source ?? "App Launch")")
        lines.append("├─ Session: \(tracker.sessionFlowId.prefix(8))...")
        lines.append("├─ Breadcrumb: \(tracker.breadcrumb.isEmpty ? pageName : tracker.breadcrumb)")

        if !metadata.isEmpty {
            lines.append("├─ Metadata:")
            for (key, value) in metadata.sorted(by: { $0.key < $1.key }) {
                lines.append("│   └─ \(key): \(value)")
            }
        }
        lines.append(separator)

        debug(.lifecycle, lines.joined(separator: "\n"), component: pageName)
    }

    func printFormattedPageExit(_ pageName: String, duration: TimeInterval?) {
        let separator = String(repeating: "═", count: 64)
        let durationStr = duration.map { formatDuration($0) } ?? "unknown"
        var lines: [String] = []

        lines.append(separator)
        lines.append("[Lifecycle] ⏹️ PAGE EXIT: \(pageName)")
        lines.append("├─ Duration: \(durationStr)")
        lines.append(separator)

        debug(.lifecycle, lines.joined(separator: "\n"), component: pageName)
    }

    func printFormattedPerformance(
        _ pageName: String,
        initToRender: TimeInterval,
        memoryMB: Double?
    ) {
        var lines: [String] = []
        lines.append("[Performance] ⏱️ \(pageName)")
        lines.append("├─ Init→Render: \(formatDuration(initToRender))")
        if let memory = memoryMB {
            lines.append("├─ Memory: \(String(format: "%.1f MB", memory))")
        }

        debug(.performance, lines.joined(separator: "\n"), component: pageName)
    }

    func printFormattedUserAction(_ action: String, target: String, page: String) {
        debug(.interaction, "[Interaction] 👆 \(action) → \(target) @ \(page)", component: page)
    }

    func printFormattedAppLaunch(deviceInfo: RuntimeLogBatchRequest.RuntimeDeviceInfo) {
        let separator = String(repeating: "═", count: 64)
        let tracker = NavigationTracker.shared
        let environment = EnvironmentManager.shared.current.rawValue
        var lines: [String] = []

        lines.append(separator)
        lines.append("[App] 🚀 APPLICATION LAUNCH")
        lines.append("├─ Version: \(deviceInfo.appVersion) (\(deviceInfo.buildNumber))")
        lines.append("├─ Environment: \(environment)")
        lines.append("├─ Device: \(deviceInfo.deviceModel) (iOS \(deviceInfo.osVersion))")
        lines.append("├─ Session: \(tracker.sessionFlowId)")
        lines.append("├─ Timestamp: \(formatTimestamp(Date()))")
        lines.append(separator)

        info(.app, lines.joined(separator: "\n"), component: "App")
    }

    // MARK: - Formatting Helpers

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.2fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return "\(minutes)m \(seconds)s"
        }
    }
}
#endif

// MARK: - Memory Helper

extension LoggingService {
    /// Get current memory usage in MB
    static func currentMemoryMB() -> Double? {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return nil }
        return Double(info.resident_size) / 1024 / 1024
    }
}
