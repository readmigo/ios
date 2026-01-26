import Foundation
import UIKit
import QuartzCore
import os.log

/// Performance metrics tracking service
/// Collects and reports client-side performance data to the backend
@MainActor
class PerformanceTracker: ObservableObject {
    static let shared = PerformanceTracker()

    private let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.readmigo", category: "performance")

    // MARK: - Metric Queues

    private var metricsQueue: [ClientMetric] = []
    private var exceptionQueue: [ExceptionReport] = []

    private let maxQueueSize = 50
    private let flushInterval: TimeInterval = 300 // 5 minutes

    private var flushTimer: Timer?
    private var displayLink: CADisplayLink?
    private var memoryTimer: Timer?

    // MARK: - FPS Tracking

    private var lastFrameTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsValues: [Double] = []
    private let fpsSampleInterval: TimeInterval = 10 // Report FPS every 10 seconds

    // MARK: - Page Load Tracking

    private var pageLoadStartTimes: [String: CFTimeInterval] = [:]

    // MARK: - App Startup

    private var appStartTime: CFTimeInterval?
    private var appReadyTime: CFTimeInterval?

    // MARK: - Persistence Keys

    private let metricsKey = "pendingPerformanceMetrics"
    private let exceptionsKey = "pendingExceptionReports"

    private init() {
        loadPendingData()
        setupAppLifecycleObservers()
        recordAppStartTime()
    }

    // MARK: - Initialization

    /// Start performance tracking
    func startTracking() {
        startFPSMonitoring()
        startMemoryMonitoring()
        startFlushTimer()
        LoggingService.shared.info(.performance, "Performance tracking started")
    }

    /// Stop performance tracking
    func stopTracking() {
        displayLink?.invalidate()
        displayLink = nil
        memoryTimer?.invalidate()
        memoryTimer = nil
        flushTimer?.invalidate()
        flushTimer = nil

        // Flush remaining data
        Task { await flush() }
    }

    // MARK: - App Startup Tracking

    private func recordAppStartTime() {
        appStartTime = CACurrentMediaTime()
    }

    /// Call this when the app is fully ready (e.g., after initial data load)
    func recordAppReady() {
        guard let startTime = appStartTime, appReadyTime == nil else { return }

        appReadyTime = CACurrentMediaTime()
        let startupTime = (appReadyTime! - startTime) * 1000 // Convert to ms

        let metric = ClientMetric(
            metricType: .appStartup,
            metricName: "app_startup_time",
            value: startupTime,
            metadata: [
                "cold_start": "true"
            ]
        )
        queueMetric(metric)

        LoggingService.shared.info(.performance, "App startup time: \(Int(startupTime))ms")
    }

    // MARK: - Page Load Tracking

    /// Start tracking page load time
    func startPageLoad(_ pageName: String) {
        pageLoadStartTimes[pageName] = CACurrentMediaTime()
    }

    /// End tracking page load time
    func endPageLoad(_ pageName: String) {
        guard let startTime = pageLoadStartTimes.removeValue(forKey: pageName) else { return }

        let loadTime = (CACurrentMediaTime() - startTime) * 1000 // Convert to ms

        let metric = ClientMetric(
            metricType: .pageLoad,
            metricName: pageName,
            value: loadTime,
            metadata: nil
        )
        queueMetric(metric)

        LoggingService.shared.debug(.performance, "\(pageName) loaded in \(Int(loadTime))ms")
    }

    /// Track a custom timing metric
    func trackTiming(name: String, durationMs: Double, metadata: [String: String]? = nil) {
        let metric = ClientMetric(
            metricType: .pageLoad,
            metricName: name,
            value: durationMs,
            metadata: metadata
        )
        queueMetric(metric)
    }

    // MARK: - FPS Monitoring

    private func startFPSMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        if lastFrameTimestamp == 0 {
            lastFrameTimestamp = displayLink.timestamp
            return
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastFrameTimestamp

        if elapsed >= fpsSampleInterval {
            let fps = Double(frameCount) / elapsed
            fpsValues.append(fps)
            frameCount = 0
            lastFrameTimestamp = displayLink.timestamp

            // Report average FPS periodically
            if fpsValues.count >= 6 { // Every minute (6 * 10 seconds)
                let avgFps = fpsValues.reduce(0, +) / Double(fpsValues.count)
                let metric = ClientMetric(
                    metricType: .fps,
                    metricName: "fps_average",
                    value: avgFps,
                    metadata: [
                        "sample_count": "\(fpsValues.count)",
                        "min_fps": String(format: "%.1f", fpsValues.min() ?? 0),
                        "max_fps": String(format: "%.1f", fpsValues.max() ?? 0)
                    ]
                )
                queueMetric(metric)
                fpsValues.removeAll()
            }
        }
    }

    // MARK: - Memory Monitoring

    private func startMemoryMonitoring() {
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordMemoryUsage()
            }
        }
    }

    private func recordMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        let metric = ClientMetric(
            metricType: .memory,
            metricName: "memory_usage",
            value: memoryUsage,
            metadata: [
                "total_memory_mb": "\(getTotalMemory())"
            ]
        )
        queueMetric(metric)
    }

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
    }

    private func getTotalMemory() -> Int {
        return Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) // MB
    }

    // MARK: - Network Tracking

    /// Track network request performance
    func trackNetworkRequest(
        endpoint: String,
        method: String,
        statusCode: Int,
        latencyMs: Double,
        requestSize: Int,
        responseSize: Int
    ) {
        let metric = ClientMetric(
            metricType: .network,
            metricName: endpoint,
            value: latencyMs,
            metadata: [
                "method": method,
                "status_code": "\(statusCode)",
                "request_size": "\(requestSize)",
                "response_size": "\(responseSize)"
            ]
        )
        queueMetric(metric)
    }

    // MARK: - Exception Tracking

    /// Report an exception
    func reportException(
        type: ExceptionType,
        message: String,
        stackTrace: String? = nil,
        metadata: [String: String]? = nil
    ) {
        let report = ExceptionReport(
            exceptionType: type,
            message: message,
            stackTrace: stackTrace,
            metadata: metadata
        )
        queueException(report)

        // Immediately flush exceptions for visibility
        Task { await flushExceptions() }
    }

    /// Report an error as exception
    func reportError(_ error: Error, context: String? = nil) {
        var metadata: [String: String] = [:]
        if let context = context {
            metadata["context"] = context
        }

        reportException(
            type: .other,
            message: error.localizedDescription,
            stackTrace: Thread.callStackSymbols.joined(separator: "\n"),
            metadata: metadata.isEmpty ? nil : metadata
        )
    }

    // MARK: - Queue Management

    private func queueMetric(_ metric: ClientMetric) {
        metricsQueue.append(metric)

        if metricsQueue.count >= maxQueueSize {
            Task { await flushMetrics() }
        }
    }

    private func queueException(_ exception: ExceptionReport) {
        exceptionQueue.append(exception)
    }

    // MARK: - Flush

    private func startFlushTimer() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.flush()
            }
        }
    }

    func flush() async {
        await flushMetrics()
        await flushExceptions()
    }

    private func flushMetrics() async {
        guard !metricsQueue.isEmpty else { return }

        let metricsToSend = metricsQueue
        metricsQueue.removeAll()

        let request = ClientMetricsBatchRequest(metrics: metricsToSend)

        do {
            let _: ClientMetricsBatchResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.metricsClient,
                method: .post,
                body: request
            )
            LoggingService.shared.info(.performance, "Flushed \(metricsToSend.count) performance metrics", component: "PerformanceTracker")
        } catch {
            LoggingService.shared.error(.performance, "Failed to flush metrics: \(error.localizedDescription)", component: "PerformanceTracker")
            // Put metrics back
            metricsQueue.insert(contentsOf: metricsToSend, at: 0)
            if metricsQueue.count > maxQueueSize * 2 {
                metricsQueue = Array(metricsQueue.suffix(maxQueueSize))
            }
        }
    }

    private func flushExceptions() async {
        guard !exceptionQueue.isEmpty else { return }

        for exception in exceptionQueue {
            do {
                let _: ExceptionReportResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.metricsException,
                    method: .post,
                    body: exception
                )
            } catch {
                LoggingService.shared.error(.performance, "Failed to report exception: \(error.localizedDescription)", component: "PerformanceTracker")
            }
        }
        exceptionQueue.removeAll()
    }

    // MARK: - Persistence

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.savePendingData()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.savePendingData()
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.flush()
            }
        }
    }

    private func savePendingData() {
        if !metricsQueue.isEmpty {
            do {
                let data = try JSONEncoder().encode(metricsQueue)
                UserDefaults.standard.set(data, forKey: metricsKey)
            } catch {
                LoggingService.shared.error(.performance, "Failed to save pending metrics: \(error.localizedDescription)", component: "PerformanceTracker")
            }
        }

        if !exceptionQueue.isEmpty {
            do {
                let data = try JSONEncoder().encode(exceptionQueue)
                UserDefaults.standard.set(data, forKey: exceptionsKey)
            } catch {
                LoggingService.shared.error(.performance, "Failed to save pending exceptions: \(error.localizedDescription)", component: "PerformanceTracker")
            }
        }
    }

    private func loadPendingData() {
        if let data = UserDefaults.standard.data(forKey: metricsKey) {
            do {
                let metrics = try JSONDecoder().decode([ClientMetric].self, from: data)
                metricsQueue.append(contentsOf: metrics)
                UserDefaults.standard.removeObject(forKey: metricsKey)
            } catch {
                LoggingService.shared.error(.performance, "Failed to load pending metrics: \(error.localizedDescription)", component: "PerformanceTracker")
            }
        }

        if let data = UserDefaults.standard.data(forKey: exceptionsKey) {
            do {
                let exceptions = try JSONDecoder().decode([ExceptionReport].self, from: data)
                exceptionQueue.append(contentsOf: exceptions)
                UserDefaults.standard.removeObject(forKey: exceptionsKey)
            } catch {
                LoggingService.shared.error(.performance, "Failed to load pending exceptions: \(error.localizedDescription)", component: "PerformanceTracker")
            }
        }
    }
}

// MARK: - Data Models

enum MetricType: String, Codable {
    case pageLoad = "PAGE_LOAD"
    case fps = "FPS"
    case memory = "MEMORY"
    case network = "NETWORK"
    case appStartup = "APP_STARTUP"
}

enum ExceptionType: String, Codable {
    case crash = "CRASH"
    case anr = "ANR"
    case jsError = "JS_ERROR"
    case networkError = "NETWORK_ERROR"
    case apiError = "API_ERROR"
    case other = "OTHER"
}

struct ClientMetric: Codable {
    let metricType: MetricType
    let metricName: String
    let value: Double
    let metadata: [String: String]?
    let timestamp: String
    let platform: String
    let appVersion: String
    let deviceModel: String

    init(
        metricType: MetricType,
        metricName: String,
        value: Double,
        metadata: [String: String]?
    ) {
        self.metricType = metricType
        self.metricName = metricName
        self.value = value
        self.metadata = metadata
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.platform = "IOS"
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.deviceModel = UIDevice.current.model
    }
}

struct ExceptionReport: Codable {
    let exceptionType: ExceptionType
    let message: String
    let stackTrace: String?
    let metadata: [String: String]?
    let timestamp: String
    let platform: String
    let appVersion: String
    let deviceModel: String
    let deviceId: String

    init(
        exceptionType: ExceptionType,
        message: String,
        stackTrace: String?,
        metadata: [String: String]?
    ) {
        self.exceptionType = exceptionType
        self.message = message
        self.stackTrace = stackTrace
        self.metadata = metadata
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.platform = "IOS"
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        self.deviceModel = UIDevice.current.model
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }
}

// MARK: - API Request/Response Models

struct ClientMetricsBatchRequest: Codable {
    let metrics: [ClientMetric]
}

struct ClientMetricsBatchResponse: Codable {
    let received: Int
    let accepted: Int
}

struct ExceptionReportResponse: Codable {
    let id: String
    let issueId: String?
}

// MARK: - SwiftUI View Extension for Page Tracking

import SwiftUI

struct PageLoadTrackingModifier: ViewModifier {
    let pageName: String
    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                if !hasAppeared {
                    PerformanceTracker.shared.startPageLoad(pageName)
                }
            }
            .task {
                if !hasAppeared {
                    hasAppeared = true
                    // Small delay to ensure view is fully rendered
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                    await MainActor.run {
                        PerformanceTracker.shared.endPageLoad(pageName)
                    }
                }
            }
    }
}

extension View {
    /// Track page load time for this view
    func trackPageLoad(_ pageName: String) -> some View {
        modifier(PageLoadTrackingModifier(pageName: pageName))
    }
}
