import SwiftUI

// MARK: - Page Turn Mode

/// 翻页模式枚举 - 支持多种翻页动画效果
enum PageTurnMode: String, CaseIterable, Codable {
    // 基础模式
    case scroll = "scroll"              // 垂直滚动
    case slide = "slide"                // 左右滑动
    case fade = "fade"                  // 淡入淡出
    case none = "none"                  // 无动画

    // 高级模式
    case pageCurl = "page_curl"         // 3D 卷曲
    case realistic = "realistic"        // 物理仿真（独创）
    case flip = "flip"                  // 3D 翻转
    case cover = "cover"                // 封面翻转
    case accordion = "accordion"        // 手风琴
    case cube = "cube"                  // 3D 立方体

    var displayName: String {
        switch self {
        case .scroll: return "垂直滚动"
        case .slide: return "左右滑动"
        case .fade: return "淡入淡出"
        case .none: return "无动画"
        case .pageCurl: return "3D 卷页"
        case .realistic: return "真实翻页"
        case .flip: return "3D 翻转"
        case .cover: return "封面翻转"
        case .accordion: return "手风琴"
        case .cube: return "3D 立方体"
        }
    }

    var icon: String {
        switch self {
        case .scroll: return "scroll"
        case .slide: return "arrow.left.arrow.right"
        case .fade: return "circle.lefthalf.filled"
        case .none: return "square"
        case .pageCurl: return "book.pages"
        case .realistic: return "book.pages.fill"
        case .flip: return "rectangle.on.rectangle.angled"
        case .cover: return "books.vertical"
        case .accordion: return "rectangle.split.3x1"
        case .cube: return "cube"
        }
    }

    /// 是否支持物理模拟
    var hasPhysics: Bool {
        switch self {
        case .pageCurl, .realistic, .flip:
            return true
        default:
            return false
        }
    }

    /// 是否支持翻页声效
    var hasSound: Bool {
        switch self {
        case .pageCurl, .realistic:
            return true
        default:
            return false
        }
    }

    /// 是否支持触觉反馈
    var hasHaptic: Bool {
        switch self {
        case .pageCurl, .realistic, .flip:
            return true
        default:
            return false
        }
    }

    /// 是否为分页模式（非连续滚动）
    var isPaged: Bool {
        self != .scroll
    }

    /// 是否支持自动翻页
    var supportsAutoPage: Bool {
        self != .scroll
    }

    /// 是否需要 3D 渲染
    var requires3D: Bool {
        switch self {
        case .pageCurl, .realistic, .flip, .cube:
            return true
        default:
            return false
        }
    }

    /// 动画默认时长
    var defaultDuration: TimeInterval {
        switch self {
        case .none: return 0
        case .fade: return 0.3
        case .slide: return 0.35
        case .pageCurl: return 0.6
        case .realistic: return 0.8
        case .flip: return 0.5
        case .cover: return 0.4
        case .accordion: return 0.5
        case .cube: return 0.6
        case .scroll: return 0
        }
    }

    /// 所有高级模式
    static var advancedModes: [PageTurnMode] {
        [.pageCurl, .realistic, .flip, .cover, .accordion, .cube]
    }

    /// 所有基础模式
    static var basicModes: [PageTurnMode] {
        [.scroll, .slide, .fade, .none]
    }
}

// MARK: - Page Turn Direction

/// 翻页方向
enum PageTurnDirection {
    case forward   // 向前翻页（下一页）
    case backward  // 向后翻页（上一页）

    var isForward: Bool {
        self == .forward
    }

    /// 动画角度（用于 3D 翻转）
    var rotationAngle: Double {
        switch self {
        case .forward: return -180
        case .backward: return 180
        }
    }
}

// MARK: - Page Turn State

/// 翻页状态
enum PageTurnState: Equatable {
    case idle                           // 空闲
    case dragging(progress: CGFloat)    // 拖动中
    case animating                      // 动画中
    case completed                      // 完成

    var isDragging: Bool {
        if case .dragging = self { return true }
        return false
    }

    var isAnimating: Bool {
        self == .animating
    }

    var isIdle: Bool {
        self == .idle
    }

    var progress: CGFloat {
        if case .dragging(let progress) = self {
            return progress
        }
        return 0
    }
}
