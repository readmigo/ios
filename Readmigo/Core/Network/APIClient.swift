import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case serverError(Int, String?)
    case networkError(Error)
    case unauthorized
    case featureNotAvailable(feature: String, minVersion: String?, reason: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return message ?? "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unauthorized:
            return "Unauthorized"
        case .featureNotAvailable(let feature, let minVersion, _):
            if let minVersion = minVersion {
                return "Feature '\(feature)' requires version \(minVersion) or higher"
            }
            return "Feature '\(feature)' is not available in this version"
        }
    }

    /// Check if this error indicates a feature is not available for the current app version
    var isFeatureNotAvailable: Bool {
        if case .featureNotAvailable = self { return true }
        return false
    }
}

/// Response structure for feature-gated 403 errors
struct FeatureErrorResponse: Decodable {
    let code: String
    let feature: String?
    let reason: String?
    let minVersion: String?
    let requiresSubscription: Bool?
    let currentVersion: String?
}

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var _baseURL: String

    /// Current base URL
    var baseURL: String { _baseURL }

    /// Update base URL (called when environment changes)
    func updateBaseURL(_ url: String) {
        _baseURL = url
    }

    private init() {
        // Use EnvironmentManager to get the correct API URL
        // Note: Since EnvironmentManager is @MainActor, we need to access it synchronously
        // The initial value comes from UserDefaults (which EnvironmentManager reads on init)
        #if DEBUG
        // In DEBUG builds, respect the stored environment preference
        if let stored = UserDefaults.standard.string(forKey: "selected_environment"),
           let env = AppEnvironment(rawValue: stored) {
            self._baseURL = env.apiBaseURL
        } else {
            // For v1 launch: Default to production for debug builds (matches EnvironmentManager)
            self._baseURL = AppEnvironment.production.apiBaseURL
        }
        #else
        // Release builds always use production
        self._baseURL = AppEnvironment.production.apiBaseURL
        #endif

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60

        // Configure URLCache for HTTP-level caching
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("URLCache", isDirectory: true)
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,   // 20MB memory
            diskCapacity: 100 * 1024 * 1024,    // 100MB disk
            directory: cacheDirectory
        )
        config.requestCachePolicy = .useProtocolCachePolicy

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        // Custom date decoder to handle ISO8601 with fractional seconds
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Fallback to standard ISO8601
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func request<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            await logError("Invalid URL for endpoint: \(endpoint)")
            throw APIError.invalidURL
        }

        // Generate correlation ID for request tracing
        let correlationId = await MainActor.run { LoggingService.shared.generateCorrelationId() }
        let startTime = Date()

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add iOS client identification headers
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Bundle-Id")
        }

        // Add version headers for version-based content distribution
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(buildNumber, forHTTPHeaderField: "X-Build-Number")

        // Add correlation ID header for backend tracing
        request.setValue(correlationId, forHTTPHeaderField: "X-Correlation-Id")

        // Add auth token if available
        if let token = await AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add Accept-Language header for i18n
        let acceptLanguage = await MainActor.run { LocalizationManager.shared.acceptLanguageHeader }
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        // Log request with NetworkLogger
        await MainActor.run {
            NetworkLogger.shared.logRequest(
                method: method.rawValue,
                endpoint: endpoint,
                correlationId: correlationId,
                headers: request.allHTTPHeaderFields,
                body: request.httpBody
            )
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await logError("No HTTP response for: \(endpoint)", correlationId: correlationId)
                throw APIError.noData
            }

            let duration = Date().timeIntervalSince(startTime)

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let result = try decoder.decode(T.self, from: data)
                    // Log successful response
                    await MainActor.run {
                        NetworkLogger.shared.logResponse(
                            method: method.rawValue,
                            endpoint: endpoint,
                            statusCode: httpResponse.statusCode,
                            duration: duration,
                            correlationId: correlationId,
                            responseSize: data.count,
                            responseBody: data
                        )
                        LoggingService.shared.clearCorrelationId()
                    }
                    return result
                } catch {
                    // Log decoding error
                    await MainActor.run {
                        NetworkLogger.shared.logError(
                            method: method.rawValue,
                            endpoint: endpoint,
                            error: APIError.decodingError(error),
                            statusCode: httpResponse.statusCode,
                            duration: duration,
                            correlationId: correlationId,
                            responseBody: data
                        )
                    }
                    throw APIError.decodingError(error)
                }
            case 401:
                await logDebug("Unauthorized, attempting token refresh for: \(endpoint)", correlationId: correlationId)
                // Try to refresh token
                if await AuthManager.shared.refreshAccessToken() {
                    await logDebug("Token refresh succeeded, retrying: \(endpoint)", correlationId: correlationId)
                    // Retry the request
                    return try await self.request(endpoint: endpoint, method: method, body: body, headers: headers)
                }
                // Log auth failure
                let authError = APIError.unauthorized
                await MainActor.run {
                    NetworkLogger.shared.logError(
                        method: method.rawValue,
                        endpoint: endpoint,
                        error: authError,
                        statusCode: 401,
                        duration: duration,
                        correlationId: correlationId,
                        responseBody: data
                    )
                }
                throw authError
            case 403:
                // Check if this is a feature-not-available error
                if let featureError = try? decoder.decode(FeatureErrorResponse.self, from: data),
                   featureError.code == "FEATURE_NOT_AVAILABLE" {
                    let error = APIError.featureNotAvailable(
                        feature: featureError.feature ?? "unknown",
                        minVersion: featureError.minVersion,
                        reason: featureError.reason
                    )
                    await MainActor.run {
                        NetworkLogger.shared.logError(
                            method: method.rawValue,
                            endpoint: endpoint,
                            error: error,
                            statusCode: 403,
                            duration: duration,
                            correlationId: correlationId,
                            responseBody: data
                        )
                    }
                    throw error
                }
                // Fall through to default handling for other 403 errors
                fallthrough
            default:
                let message = try? decoder.decode(ErrorResponse.self, from: data).message
                let serverError = APIError.serverError(httpResponse.statusCode, message)
                // Log server error
                await MainActor.run {
                    NetworkLogger.shared.logError(
                        method: method.rawValue,
                        endpoint: endpoint,
                        error: serverError,
                        statusCode: httpResponse.statusCode,
                        duration: duration,
                        correlationId: correlationId,
                        responseBody: data
                    )
                }
                throw serverError
            }
        } catch let error as APIError {
            await MainActor.run { LoggingService.shared.clearCorrelationId() }
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            // Log network error
            await MainActor.run {
                NetworkLogger.shared.logError(
                    method: method.rawValue,
                    endpoint: endpoint,
                    error: error,
                    statusCode: nil,
                    duration: duration,
                    correlationId: correlationId
                )
                LoggingService.shared.clearCorrelationId()
            }
            throw APIError.networkError(error)
        }
    }

    // MARK: - Private Logging Helpers

    private func logDebug(_ message: String, correlationId: String? = nil) async {
        await MainActor.run {
            LoggingService.shared.debug(.network, message, component: "APIClient")
        }
    }

    private func logError(_ message: String, correlationId: String? = nil) async {
        await MainActor.run {
            LoggingService.shared.error(.network, message, component: "APIClient")
        }
    }

    func requestVoid(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil
    ) async throws {
        let _: EmptyResponse = try await request(endpoint: endpoint, method: method, body: body)
    }

    /// Make a request without authentication (for public endpoints like guest feedback)
    func requestWithoutAuth<T: Decodable>(
        endpoint: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        headers: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            await logError("Invalid URL for endpoint: \(endpoint)")
            throw APIError.invalidURL
        }

        let correlationId = await MainActor.run { LoggingService.shared.generateCorrelationId() }
        let startTime = Date()

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add iOS client identification headers
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Bundle-Id")
        }

        // Add version headers
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue(buildNumber, forHTTPHeaderField: "X-Build-Number")

        // Add correlation ID header
        request.setValue(correlationId, forHTTPHeaderField: "X-Correlation-Id")

        // Note: NO authentication header added - this is intentional for public endpoints

        // Add Accept-Language header for i18n
        let acceptLanguage = await MainActor.run { LocalizationManager.shared.acceptLanguageHeader }
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")

        // Add custom headers
        headers?.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add body if present
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        // Log request
        await MainActor.run {
            NetworkLogger.shared.logRequest(
                method: method.rawValue,
                endpoint: endpoint,
                correlationId: correlationId,
                headers: request.allHTTPHeaderFields,
                body: request.httpBody
            )
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await logError("No HTTP response for: \(endpoint)", correlationId: correlationId)
                throw APIError.noData
            }

            let duration = Date().timeIntervalSince(startTime)

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let result = try decoder.decode(T.self, from: data)
                    await MainActor.run {
                        NetworkLogger.shared.logResponse(
                            method: method.rawValue,
                            endpoint: endpoint,
                            statusCode: httpResponse.statusCode,
                            duration: duration,
                            correlationId: correlationId,
                            responseSize: data.count,
                            responseBody: data
                        )
                        LoggingService.shared.clearCorrelationId()
                    }
                    return result
                } catch {
                    await MainActor.run {
                        NetworkLogger.shared.logError(
                            method: method.rawValue,
                            endpoint: endpoint,
                            error: APIError.decodingError(error),
                            statusCode: httpResponse.statusCode,
                            duration: duration,
                            correlationId: correlationId,
                            responseBody: data
                        )
                    }
                    throw APIError.decodingError(error)
                }
            default:
                let message = try? decoder.decode(ErrorResponse.self, from: data).message
                let serverError = APIError.serverError(httpResponse.statusCode, message)
                await MainActor.run {
                    NetworkLogger.shared.logError(
                        method: method.rawValue,
                        endpoint: endpoint,
                        error: serverError,
                        statusCode: httpResponse.statusCode,
                        duration: duration,
                        correlationId: correlationId,
                        responseBody: data
                    )
                }
                throw serverError
            }
        } catch let error as APIError {
            await MainActor.run { LoggingService.shared.clearCorrelationId() }
            throw error
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            await MainActor.run {
                NetworkLogger.shared.logError(
                    method: method.rawValue,
                    endpoint: endpoint,
                    error: error,
                    statusCode: nil,
                    duration: duration,
                    correlationId: correlationId
                )
                LoggingService.shared.clearCorrelationId()
            }
            throw APIError.networkError(error)
        }
    }

    // MARK: - User Activity & Profile

    /// Update user activity (lastActiveAt)
    func updateActivity() async throws {
        struct ActivityResponse: Decodable {
            let success: Bool
            let message: String
        }

        let _: ActivityResponse = try await request(
            endpoint: "/users/me/activity",
            method: .patch
        )
    }

    /// Get user profile information
    func getUserProfile() async throws -> UserProfile {
        return try await request(
            endpoint: "/users/me/user-profile",
            method: .get
        )
    }

    /// Update user profile information
    func updateUserProfile(_ profile: UserProfileUpdate) async throws -> UserProfile {
        return try await request(
            endpoint: "/users/me/user-profile",
            method: .patch,
            body: profile
        )
    }

    /// Upload a file using multipart form data
    func uploadMultipart<T: Decodable>(
        endpoint: String,
        fileData: Data,
        fileName: String,
        mimeType: String,
        additionalFields: [String: String]? = nil
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            await logError("Invalid URL for endpoint: \(endpoint)")
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Add iOS client identification headers
        request.setValue("ios", forHTTPHeaderField: "X-Platform")
        if let bundleId = Bundle.main.bundleIdentifier {
            request.setValue(bundleId, forHTTPHeaderField: "X-Bundle-Id")
        }

        // Add auth token if available
        if let token = await AuthManager.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add Accept-Language header for i18n
        let acceptLanguage = await MainActor.run { LocalizationManager.shared.acceptLanguageHeader }
        request.setValue(acceptLanguage, forHTTPHeaderField: "Accept-Language")

        // Build multipart form data
        var body = Data()

        // Add additional fields
        if let fields = additionalFields {
            for (key, value) in fields {
                body.append("--\(boundary)\r\n".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
                body.append("\(value)\r\n".data(using: .utf8)!)
            }
        }

        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        await logDebug("Multipart upload started: \(endpoint)")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                await logError("No HTTP response for: \(endpoint)")
                throw APIError.noData
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let result = try decoder.decode(T.self, from: data)
                    await logDebug("Multipart upload succeeded: \(endpoint)")
                    return result
                } catch {
                    await logError("Decoding error for \(endpoint): \(error.localizedDescription)")
                    throw APIError.decodingError(error)
                }
            case 401:
                if await AuthManager.shared.refreshAccessToken() {
                    return try await self.uploadMultipart(
                        endpoint: endpoint,
                        fileData: fileData,
                        fileName: fileName,
                        mimeType: mimeType,
                        additionalFields: additionalFields
                    )
                }
                throw APIError.unauthorized
            default:
                let message = try? decoder.decode(ErrorResponse.self, from: data).message
                await logError("Server error for \(endpoint): \(httpResponse.statusCode)")
                throw APIError.serverError(httpResponse.statusCode, message)
            }
        } catch let error as APIError {
            throw error
        } catch {
            await logError("Network error for \(endpoint): \(error.localizedDescription)")
            throw APIError.networkError(error)
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct EmptyResponse: Decodable {}

struct ErrorResponse: Decodable {
    let message: String
    let statusCode: Int?
}
