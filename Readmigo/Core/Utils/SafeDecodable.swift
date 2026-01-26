import Foundation

// MARK: - SafeDecodable

/// A property wrapper that provides a default value when decoding fails.
/// Useful for optional fields that should have a fallback value.
///
/// Usage:
/// ```swift
/// struct User: Codable {
///     let id: String
///     @SafeDecodable var isVerified: Bool = false
///     @SafeDecodable var followerCount: Int = 0
/// }
/// ```
@propertyWrapper
public struct SafeDecodable<T: Codable>: Codable {
    public var wrappedValue: T

    public init(wrappedValue: T) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = (try? container.decode(T.self)) ?? wrappedValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

// Make SafeDecodable work with KeyedDecodingContainer
extension KeyedDecodingContainer {
    public func decode<T: Codable>(
        _ type: SafeDecodable<T>.Type,
        forKey key: Key
    ) throws -> SafeDecodable<T> {
        if let value = try? decodeIfPresent(T.self, forKey: key) {
            return SafeDecodable(wrappedValue: value)
        }
        // Return a default instance - this requires T to have a default
        // The actual default is set by the property declaration
        throw DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: ""))
    }
}

// MARK: - UnknownCaseCodable

/// A property wrapper for enums that gracefully handles unknown raw values.
/// When an unknown value is encountered, the wrapped value becomes nil.
///
/// Usage:
/// ```swift
/// enum Status: String, Codable {
///     case active = "ACTIVE"
///     case inactive = "INACTIVE"
/// }
///
/// struct User: Codable {
///     @UnknownCaseCodable var status: Status?
/// }
/// ```
@propertyWrapper
public struct UnknownCaseCodable<T: RawRepresentable & Codable>: Codable
    where T.RawValue: Codable
{
    public var wrappedValue: T?

    public init(wrappedValue: T?) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode the raw value
        if let rawValue = try? container.decode(T.RawValue.self) {
            // Try to create the enum case
            self.wrappedValue = T(rawValue: rawValue)
            // If rawValue is valid but enum case doesn't exist, wrappedValue will be nil
        } else {
            // If decoding raw value fails, set to nil
            self.wrappedValue = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let value = wrappedValue {
            try container.encode(value.rawValue)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - DefaultEmptyArray

/// A property wrapper that defaults to an empty array when decoding fails.
///
/// Usage:
/// ```swift
/// struct Response: Codable {
///     @DefaultEmptyArray var items: [Item]
/// }
/// ```
@propertyWrapper
public struct DefaultEmptyArray<T: Codable>: Codable {
    public var wrappedValue: [T]

    public init(wrappedValue: [T] = []) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = (try? container.decode([T].self)) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode<T: Codable>(
        _ type: DefaultEmptyArray<T>.Type,
        forKey key: Key
    ) throws -> DefaultEmptyArray<T> {
        if let value = try? decodeIfPresent([T].self, forKey: key) {
            return DefaultEmptyArray(wrappedValue: value)
        }
        return DefaultEmptyArray(wrappedValue: [])
    }
}

// MARK: - DefaultEmptyString

/// A property wrapper that defaults to an empty string when decoding fails.
///
/// Usage:
/// ```swift
/// struct User: Codable {
///     @DefaultEmptyString var bio: String
/// }
/// ```
@propertyWrapper
public struct DefaultEmptyString: Codable {
    public var wrappedValue: String

    public init(wrappedValue: String = "") {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = (try? container.decode(String.self)) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode(
        _ type: DefaultEmptyString.Type,
        forKey key: Key
    ) throws -> DefaultEmptyString {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return DefaultEmptyString(wrappedValue: value)
        }
        return DefaultEmptyString(wrappedValue: "")
    }
}

// MARK: - DefaultZero

/// A property wrapper that defaults to zero when decoding fails.
///
/// Usage:
/// ```swift
/// struct Stats: Codable {
///     @DefaultZero var count: Int
///     @DefaultZero var score: Double
/// }
/// ```
@propertyWrapper
public struct DefaultZero<T: Codable & Numeric>: Codable {
    public var wrappedValue: T

    public init(wrappedValue: T = .zero) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = (try? container.decode(T.self)) ?? .zero
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode<T: Codable & Numeric>(
        _ type: DefaultZero<T>.Type,
        forKey key: Key
    ) throws -> DefaultZero<T> {
        if let value = try? decodeIfPresent(T.self, forKey: key) {
            return DefaultZero(wrappedValue: value)
        }
        return DefaultZero(wrappedValue: .zero)
    }
}

// MARK: - DefaultFalse

/// A property wrapper that defaults to false when decoding fails.
///
/// Usage:
/// ```swift
/// struct Settings: Codable {
///     @DefaultFalse var isEnabled: Bool
/// }
/// ```
@propertyWrapper
public struct DefaultFalse: Codable {
    public var wrappedValue: Bool

    public init(wrappedValue: Bool = false) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.wrappedValue = (try? container.decode(Bool.self)) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode(
        _ type: DefaultFalse.Type,
        forKey key: Key
    ) throws -> DefaultFalse {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return DefaultFalse(wrappedValue: value)
        }
        return DefaultFalse(wrappedValue: false)
    }
}

// MARK: - SafeDate

/// A property wrapper that provides fault-tolerant date decoding.
/// Tries multiple date formats and defaults to current date if all fail.
///
/// Usage:
/// ```swift
/// struct Event: Codable {
///     @SafeDate var createdAt: Date
/// }
/// ```
@propertyWrapper
public struct SafeDate: Codable {
    public var wrappedValue: Date

    private static let formatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        return [withFractional, withoutFractional]
    }()

    public init(wrappedValue: Date = Date()) {
        self.wrappedValue = wrappedValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode as Date first (in case decoder has custom date strategy)
        if let date = try? container.decode(Date.self) {
            self.wrappedValue = date
            return
        }

        // Try to decode as String and parse
        if let dateString = try? container.decode(String.self) {
            for formatter in Self.formatters {
                if let date = formatter.date(from: dateString) {
                    self.wrappedValue = date
                    return
                }
            }
        }

        // Default to current date if all parsing fails
        self.wrappedValue = Date()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

extension KeyedDecodingContainer {
    public func decode(
        _ type: SafeDate.Type,
        forKey key: Key
    ) throws -> SafeDate {
        if let dateString = try? decodeIfPresent(String.self, forKey: key) {
            for formatter in SafeDate.formatters {
                if let date = formatter.date(from: dateString) {
                    return SafeDate(wrappedValue: date)
                }
            }
        }

        if let date = try? decodeIfPresent(Date.self, forKey: key) {
            return SafeDate(wrappedValue: date)
        }

        return SafeDate(wrappedValue: Date())
    }

    private static var formatters: [ISO8601DateFormatter] {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]

        return [withFractional, withoutFractional]
    }
}
