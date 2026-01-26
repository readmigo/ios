import CoreHaptics
import UIKit

// MARK: - Page Turn Haptic Engine

/// 翻页触觉反馈引擎
class PageTurnHapticEngine: ObservableObject {

    // MARK: - Properties

    /// 是否启用触觉反馈
    @Published var isEnabled: Bool = true

    /// 触觉强度 (0-1)
    @Published var intensity: Float = 1.0

    // MARK: - Private Properties

    private var engine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?
    private var supportsHaptics: Bool = false

    // MARK: - Initialization

    init() {
        setupHapticEngine()
    }

    // MARK: - Setup

    private func setupHapticEngine() {
        // 检查设备是否支持 Core Haptics
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

        guard supportsHaptics else {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Device does not support Core Haptics", component: "PageTurnHapticEngine") }
            return
        }

        do {
            engine = try CHHapticEngine()

            // 配置引擎
            engine?.playsHapticsOnly = true
            engine?.isAutoShutdownEnabled = true

            // 设置重置处理器
            engine?.resetHandler = { [weak self] in
                do {
                    try self?.engine?.start()
                } catch {
                    Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to restart haptic engine: \(error)", component: "PageTurnHapticEngine") }
                }
            }

            // 启动引擎
            try engine?.start()
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to create haptic engine: \(error)", component: "PageTurnHapticEngine") }
            supportsHaptics = false
        }
    }

    // MARK: - Public Methods

    /// 播放翻页完成触觉 - 模拟纸张翻转的触感
    func playPageTurnHaptic() {
        guard isEnabled && supportsHaptics else {
            playFallbackHaptic()
            return
        }

        do {
            let pattern = try createPageTurnPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to play page turn haptic: \(error)", component: "PageTurnHapticEngine") }
            playFallbackHaptic()
        }
    }

    /// 播放翻页开始触觉
    func playPageLiftHaptic() {
        guard isEnabled && supportsHaptics else {
            playFallbackHaptic(style: .light)
            return
        }

        do {
            let pattern = try createLiftPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to play lift haptic: \(error)", component: "PageTurnHapticEngine") }
            playFallbackHaptic(style: .light)
        }
    }

    /// 播放翻页落下触觉
    func playPageDropHaptic() {
        guard isEnabled && supportsHaptics else {
            playFallbackHaptic(style: .medium)
            return
        }

        do {
            let pattern = try createDropPattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to play drop haptic: \(error)", component: "PageTurnHapticEngine") }
            playFallbackHaptic(style: .medium)
        }
    }

    /// 实时触觉反馈（跟随手指拖动）
    /// - Parameter progress: 翻页进度 (0-1)
    func playDragHaptic(progress: CGFloat) {
        guard isEnabled && supportsHaptics else { return }

        // 每 10% 进度播放一次轻微触觉
        let step = Int(progress * 10)
        let previousStep = Int((progress - 0.05) * 10)

        if step != previousStep && step > 0 {
            playLightTick()
        }
    }

    /// 开始连续触觉反馈
    /// - Parameter intensity: 强度 (0-1)
    func startContinuousHaptic(intensity: Float) {
        guard isEnabled && supportsHaptics else { return }

        do {
            let pattern = try createContinuousPattern(intensity: intensity)
            continuousPlayer = try engine?.makeAdvancedPlayer(with: pattern)
            try continuousPlayer?.start(atTime: CHHapticTimeImmediate)
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to start continuous haptic: \(error)", component: "PageTurnHapticEngine") }
        }
    }

    /// 更新连续触觉强度
    /// - Parameter intensity: 强度 (0-1)
    func updateContinuousHaptic(intensity: Float) {
        guard let player = continuousPlayer else { return }

        do {
            let intensityParam = CHHapticDynamicParameter(
                parameterID: .hapticIntensityControl,
                value: intensity * self.intensity,
                relativeTime: 0
            )
            try player.sendParameters([intensityParam], atTime: CHHapticTimeImmediate)
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to update continuous haptic: \(error)", component: "PageTurnHapticEngine") }
        }
    }

    /// 停止连续触觉反馈
    func stopContinuousHaptic() {
        do {
            try continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
            continuousPlayer = nil
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to stop continuous haptic: \(error)", component: "PageTurnHapticEngine") }
        }
    }

    /// 播放章节切换触觉
    func playChapterChangeHaptic() {
        guard isEnabled && supportsHaptics else {
            playFallbackHaptic(style: .heavy)
            return
        }

        do {
            let pattern = try createChapterChangePattern()
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to play chapter change haptic: \(error)", component: "PageTurnHapticEngine") }
            playFallbackHaptic(style: .heavy)
        }
    }

    // MARK: - Pattern Creation

    private func createPageTurnPattern() throws -> CHHapticPattern {
        // 模拟纸张翻转的三阶段触觉
        let events: [CHHapticEvent] = [
            // 1. 开始接触 - 轻触
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0
            ),

            // 2. 翻转中 - 持续的轻微振动
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0.05,
                duration: 0.15
            ),

            // 3. 落下 - 较强的触感
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                ],
                relativeTime: 0.2
            )
        ]

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createLiftPattern() throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3 * intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
            ],
            relativeTime: 0
        )

        return try CHHapticPattern(events: [event], parameters: [])
    }

    private func createDropPattern() throws -> CHHapticPattern {
        let events: [CHHapticEvent] = [
            // 主要落下触感
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6)
                ],
                relativeTime: 0
            ),
            // 回弹
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.2 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
                ],
                relativeTime: 0.08
            )
        ]

        return try CHHapticPattern(events: events, parameters: [])
    }

    private func createContinuousPattern(intensity: Float) throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * self.intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
            ],
            relativeTime: 0,
            duration: 30 // 最大持续时间
        )

        return try CHHapticPattern(events: [event], parameters: [])
    }

    private func createChapterChangePattern() throws -> CHHapticPattern {
        let events: [CHHapticEvent] = [
            // 双击模式
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0
            ),
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                ],
                relativeTime: 0.1
            )
        ]

        return try CHHapticPattern(events: events, parameters: [])
    }

    // MARK: - Helper Methods

    private func playLightTick() {
        do {
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.15 * intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                ],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: CHHapticTimeImmediate)
        } catch {
            // 静默失败
        }
    }

    private func playFallbackHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        guard isEnabled else { return }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: CGFloat(intensity))
    }

    // MARK: - Cleanup

    func stopEngine() {
        stopContinuousHaptic()
        engine?.stop()
    }

    func restartEngine() {
        do {
            try engine?.start()
        } catch {
            Task { @MainActor in LoggingService.shared.debug(.reading, "Failed to restart haptic engine: \(error)", component: "PageTurnHapticEngine") }
        }
    }
}
