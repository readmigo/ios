import Foundation

/// Network request/response logger with formatted debug output
@MainActor
class NetworkLogger {
    static let shared = NetworkLogger()

    // MARK: - Configuration

    struct Config {
        static var logRequestBody = true
        static var logResponseBody = true
        static var maxBodyLength = 5000
        static var logHeaders = true
        static var sensitiveHeaders: Set<String> = ["Authorization", "Cookie", "X-Auth-Token"]

        /// Enable verbose logging for DEBUG builds only
        static var verboseLogging: Bool {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
    }

    private init() {}

    // MARK: - Public Methods

    /// Log an outgoing request
    func logRequest(
        method: String,
        endpoint: String,
        correlationId: String,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) {
        if Config.verboseLogging {
            printFormattedRequest(
                method: method,
                endpoint: endpoint,
                correlationId: correlationId,
                headers: headers,
                body: body
            )
        }

        LoggingService.shared.debug(.network,
            "→ \(method) \(endpoint)",
            component: "APIClient",
            metadata: [
                "correlationId": correlationId,
                "method": method,
                "endpoint": endpoint
            ])
    }

    /// Log a successful response
    func logResponse(
        method: String,
        endpoint: String,
        statusCode: Int,
        duration: TimeInterval,
        correlationId: String,
        responseSize: Int? = nil,
        responseBody: Data? = nil
    ) {
        if Config.verboseLogging {
            printFormattedResponse(
                method: method,
                endpoint: endpoint,
                statusCode: statusCode,
                duration: duration,
                correlationId: correlationId,
                responseSize: responseSize,
                responseBody: responseBody
            )
        }

        LoggingService.shared.info(.network,
            "← \(method) \(endpoint) [\(statusCode)] \(formatDuration(duration))",
            component: "APIClient",
            metadata: [
                "correlationId": correlationId,
                "statusCode": "\(statusCode)",
                "duration_ms": "\(Int(duration * 1000))",
                "responseSize": responseSize.map { "\($0)" } ?? "unknown"
            ])
    }

    /// Log a failed request
    func logError(
        method: String,
        endpoint: String,
        error: Error,
        statusCode: Int? = nil,
        duration: TimeInterval,
        correlationId: String,
        responseBody: Data? = nil
    ) {
        if Config.verboseLogging {
            printFormattedError(
                method: method,
                endpoint: endpoint,
                error: error,
                statusCode: statusCode,
                duration: duration,
                correlationId: correlationId,
                responseBody: responseBody
            )
        }

        LoggingService.shared.error(.network,
            "✗ \(method) \(endpoint) - \(error.localizedDescription)",
            component: "APIClient",
            metadata: [
                "correlationId": correlationId,
                "statusCode": statusCode.map { "\($0)" } ?? "N/A",
                "duration_ms": "\(Int(duration * 1000))",
                "errorType": String(describing: type(of: error)),
                "errorMessage": error.localizedDescription
            ])
    }
}

// MARK: - Debug Formatters

extension NetworkLogger {

    private func printFormattedRequest(
        method: String,
        endpoint: String,
        correlationId: String,
        headers: [String: String]?,
        body: Data?
    ) {
        let separator = String(repeating: "─", count: 64)
        var lines: [String] = []

        lines.append(separator)
        lines.append("[Network] 📤 REQUEST")
        lines.append("├─ \(method) \(endpoint)")
        lines.append("├─ CorrelationId: \(correlationId.prefix(8))...")
        lines.append("├─ Timestamp: \(formattedTimestamp())")

        // Print safe headers
        if Config.logHeaders, let headers = headers {
            let safeHeaders = headers.filter { !Config.sensitiveHeaders.contains($0.key) }
            if !safeHeaders.isEmpty {
                lines.append("├─ Headers:")
                for (key, value) in safeHeaders.sorted(by: { $0.key < $1.key }).prefix(5) {
                    lines.append("│   └─ \(key): \(value)")
                }
            }
        }

        // Print request body
        if Config.logRequestBody, let body = body, let jsonString = prettyPrintJSON(body, maxLength: Config.maxBodyLength) {
            lines.append("├─ Body:")
            jsonString.split(separator: "\n").forEach { line in
                lines.append("│   \(line)")
            }
        }
        lines.append(separator)

        LoggingService.shared.debug(.network, lines.joined(separator: "\n"), component: "NetworkLogger")
    }

    private func printFormattedResponse(
        method: String,
        endpoint: String,
        statusCode: Int,
        duration: TimeInterval,
        correlationId: String,
        responseSize: Int?,
        responseBody: Data?
    ) {
        let separator = String(repeating: "─", count: 64)
        let statusEmoji = statusCode < 300 ? "✅" : (statusCode < 400 ? "⚠️" : "❌")
        var lines: [String] = []

        lines.append(separator)
        lines.append("[Network] 📥 RESPONSE \(statusEmoji)")
        lines.append("├─ \(method) \(endpoint)")
        lines.append("├─ Status: \(statusCode) \(httpStatusText(statusCode))")
        lines.append("├─ Duration: \(formatDuration(duration))")
        lines.append("├─ Size: \(formatBytes(responseSize))")
        lines.append("├─ CorrelationId: \(correlationId.prefix(8))...")

        // Print response body preview
        if Config.logResponseBody, let body = responseBody, let jsonString = prettyPrintJSON(body, maxLength: Config.maxBodyLength) {
            lines.append("├─ Body (preview):")
            let bodyLines = jsonString.split(separator: "\n")
            bodyLines.prefix(15).forEach { line in
                lines.append("│   \(line)")
            }
            if bodyLines.count > 15 {
                lines.append("│   ... (truncated)")
            }
        }
        lines.append(separator)

        LoggingService.shared.debug(.network, lines.joined(separator: "\n"), component: "NetworkLogger")
    }

    private func printFormattedError(
        method: String,
        endpoint: String,
        error: Error,
        statusCode: Int?,
        duration: TimeInterval,
        correlationId: String,
        responseBody: Data?
    ) {
        let separator = String(repeating: "═", count: 64)
        var lines: [String] = []

        lines.append(separator)
        lines.append("[Network] ❌ ERROR")
        lines.append("├─ \(method) \(endpoint)")
        lines.append("├─ Status: \(statusCode.map { "\($0)" } ?? "N/A")")
        lines.append("├─ Duration: \(formatDuration(duration))")
        lines.append("├─ Error Type: \(String(describing: type(of: error)))")
        lines.append("├─ Message: \(error.localizedDescription)")
        lines.append("├─ CorrelationId: \(correlationId.prefix(8))...")

        // Print error response body
        if let body = responseBody, let jsonString = prettyPrintJSON(body, maxLength: 500) {
            lines.append("├─ Response Body:")
            jsonString.split(separator: "\n").forEach { line in
                lines.append("│   \(line)")
            }
        }
        lines.append(separator)

        LoggingService.shared.error(.network, lines.joined(separator: "\n"), component: "NetworkLogger")
    }
}

// MARK: - Formatting Helpers

extension NetworkLogger {

    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }

    private func formatBytes(_ bytes: Int?) -> String {
        guard let bytes = bytes else { return "unknown" }
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
        }
    }

    private func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return ""
        }
    }

    private func prettyPrintJSON(_ data: Data, maxLength: Int) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
              var string = String(data: prettyData, encoding: .utf8) else {
            return nil
        }

        if string.count > maxLength {
            string = String(string.prefix(maxLength)) + "\n... (truncated)"
        }
        return string
    }
}
