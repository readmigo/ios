import Foundation

/// 账号类型枚举
/// - g: 游客账号 (Guest)
/// - r: 正式注册账号 (Registered)
/// - s: 系统账号 (System)
/// - d: 已注销账号 (Deleted)
enum AccountType: String, CaseIterable {
    case guest = "g"
    case registered = "r"
    case system = "s"
    case deleted = "d"

    var displayName: String {
        switch self {
        case .guest: return "Guest Account"
        case .registered: return "Registered Account"
        case .system: return "System Account"
        case .deleted: return "Deleted Account"
        }
    }

    var displayNameZh: String {
        switch self {
        case .guest: return "游客账号"
        case .registered: return "正式账号"
        case .system: return "系统账号"
        case .deleted: return "已注销账号"
        }
    }
}

/// 解析后的账号ID结构
struct ParsedAccountId {
    let type: AccountType
    let ulid: String
    let timestamp: Date
}

/// 账号ID服务
///
/// 负责生成和解析账号ID
/// 格式: {type}{ulid} (27 chars)
/// 示例: g01HV6BGKCPG3M8QDJX9Y7CJ5ZA
///
/// 特点:
/// - 精简高效: 27字符，比旧格式节省27%带宽
/// - 类型可识别: 首字符区分账号类型
/// - 全局唯一: ULID保证分布式唯一性
/// - 时间有序: 支持按创建时间排序
final class AccountIdService {

    static let shared = AccountIdService()
    private init() {}

    // ULID 使用 Crockford's Base32 编码，排除 I, L, O, U 避免混淆
    private static let crockfordChars = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    // 账号ID格式正则: 类型前缀(1字符) + ULID(26字符)
    private let idPattern = "^[grsd][0-9A-HJKMNP-TV-Z]{26}$"

    // MARK: - ID Generation (主要由后端生成，客户端仅用于本地游客账号)

    /// 生成本地游客账号ID
    /// 注意: 正式使用时应从后端获取ID，此方法仅用于离线场景
    func generateLocalGuestId() -> String {
        return "\(AccountType.guest.rawValue)\(generateULID())"
    }

    // MARK: - Validation

    /// 验证账号ID格式是否有效
    func isValid(_ id: String) -> Bool {
        guard !id.isEmpty else { return false }
        return id.range(of: idPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Parsing

    /// 解析账号ID，提取类型和时间戳信息
    func parse(_ id: String) -> ParsedAccountId? {
        guard isValid(id) else { return nil }

        let typeChar = String(id.prefix(1)).lowercased()
        let ulidPart = String(id.dropFirst())

        guard let type = AccountType(rawValue: typeChar),
              let timestamp = decodeTimestamp(from: ulidPart) else {
            return nil
        }

        return ParsedAccountId(type: type, ulid: ulidPart, timestamp: timestamp)
    }

    // MARK: - Type Checking

    /// 获取账号类型
    func getType(_ id: String) -> AccountType? {
        guard isValid(id), let first = id.first else { return nil }
        return AccountType(rawValue: String(first).lowercased())
    }

    /// 判断是否为游客账号
    func isGuest(_ id: String) -> Bool {
        return id.lowercased().hasPrefix("g") && isValid(id)
    }

    /// 判断是否为正式注册账号
    func isRegistered(_ id: String) -> Bool {
        return id.lowercased().hasPrefix("r") && isValid(id)
    }

    /// 判断是否为系统账号
    func isSystem(_ id: String) -> Bool {
        return id.lowercased().hasPrefix("s") && isValid(id)
    }

    /// 判断是否为已注销账号
    func isDeleted(_ id: String) -> Bool {
        return id.lowercased().hasPrefix("d") && isValid(id)
    }

    /// 从账号ID中提取创建时间
    func getCreatedAt(_ id: String) -> Date? {
        return parse(id)?.timestamp
    }

    // MARK: - ULID Generation & Decoding

    /// 生成 ULID
    /// ULID 格式: 10字符时间戳 + 16字符随机数 = 26字符
    private func generateULID() -> String {
        let chars = Self.crockfordChars
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        var result = ""

        // 时间戳部分 (10 chars, 高位在前)
        var t = timestamp
        var timeChars = ""
        for _ in 0..<10 {
            timeChars = String(chars[Int(t & 0x1F)]) + timeChars
            t >>= 5
        }
        result = timeChars

        // 随机数部分 (16 chars)
        for _ in 0..<16 {
            result += String(chars[Int.random(in: 0..<32)])
        }

        return result
    }

    /// 从 ULID 解码时间戳
    private func decodeTimestamp(from ulid: String) -> Date? {
        guard ulid.count == 26 else { return nil }

        let chars = Self.crockfordChars
        var timestamp: UInt64 = 0

        // 解码前10个字符为时间戳
        for char in ulid.prefix(10) {
            let upperChar = char.uppercased().first ?? " "
            guard let idx = chars.firstIndex(of: upperChar) else { return nil }
            timestamp = (timestamp << 5) | UInt64(idx)
        }

        return Date(timeIntervalSince1970: Double(timestamp) / 1000)
    }
}

// MARK: - Extensions

extension AccountIdService {
    /// 格式化账号ID用于显示（可选遮罩）
    func formatForDisplay(_ id: String, masked: Bool = false) -> String {
        guard isValid(id) else { return id }

        if masked {
            // 显示类型前缀 + 前4位 + ... + 后4位
            let prefix = String(id.prefix(5))
            let suffix = String(id.suffix(4))
            return "\(prefix)...\(suffix)"
        }

        return id
    }

    /// 获取账号类型标签
    func getTypeLabel(_ id: String) -> String? {
        guard let type = getType(id) else { return nil }
        return type.displayName
    }

    /// 获取账号类型中文标签
    func getTypeLabelZh(_ id: String) -> String? {
        guard let type = getType(id) else { return nil }
        return type.displayNameZh
    }
}
