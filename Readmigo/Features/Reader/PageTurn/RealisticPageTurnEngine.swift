import SwiftUI
import Combine

// MARK: - Realistic Page Turn Engine

/// 物理仿真翻页引擎 - 实现真实的纸张翻页效果
@MainActor
class RealisticPageTurnEngine: ObservableObject {

    // MARK: - Physics Parameters

    /// 纸张刚度 (0-1)，值越大纸张越硬
    @Published var paperStiffness: CGFloat = 0.8

    /// 页面重量 (0-1)
    @Published var pageWeight: CGFloat = 0.5

    /// 空气阻力 (0-1)
    @Published var airResistance: CGFloat = 0.3

    /// 重力加速度
    @Published var gravity: CGFloat = 9.8

    /// 弹性系数
    @Published var elasticity: CGFloat = 0.6

    // MARK: - State

    /// 当前翻页进度 (0-1)
    @Published private(set) var currentProgress: CGFloat = 0

    /// 当前速度
    @Published private(set) var velocity: CGFloat = 0

    /// 是否正在动画
    @Published private(set) var isAnimating: Bool = false

    /// 当前翻页方向
    @Published private(set) var direction: PageTurnDirection = .forward

    /// 翻页状态
    @Published private(set) var state: PageTurnState = .idle

    // MARK: - Mesh Data

    /// 页面网格点（用于 3D 变形）
    private(set) var meshPoints: [[CGPoint]] = []

    /// 网格分辨率
    let meshResolution: Int = 20

    // MARK: - Private Properties

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var targetProgress: CGFloat = 0
    private var completionHandler: (() -> Void)?

    // MARK: - Initialization

    init() {
        initializeMesh()
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Mesh Initialization

    private func initializeMesh() {
        meshPoints = (0..<meshResolution).map { row in
            (0..<meshResolution).map { col in
                CGPoint(
                    x: CGFloat(col) / CGFloat(meshResolution - 1),
                    y: CGFloat(row) / CGFloat(meshResolution - 1)
                )
            }
        }
    }

    // MARK: - Public Methods

    /// 开始翻页动画
    /// - Parameters:
    ///   - direction: 翻页方向
    ///   - completion: 完成回调
    func startPageTurn(direction: PageTurnDirection, completion: (() -> Void)? = nil) {
        guard !isAnimating else { return }

        self.direction = direction
        self.completionHandler = completion
        self.isAnimating = true
        self.state = .animating

        // 设置目标进度
        targetProgress = direction == .forward ? 1.0 : 0.0

        // 初始速度
        velocity = direction == .forward ? 2.0 : -2.0

        startDisplayLink()
    }

    /// 开始拖动
    /// - Parameter progress: 初始进度
    func beginDrag(at progress: CGFloat) {
        stopAnimation()
        currentProgress = progress
        state = .dragging(progress: progress)
    }

    /// 更新拖动进度
    /// - Parameter progress: 当前进度
    func updateDrag(to progress: CGFloat) {
        guard case .dragging = state else { return }
        currentProgress = max(0, min(1, progress))
        state = .dragging(progress: currentProgress)
        updateMesh()
    }

    /// 结束拖动
    /// - Parameters:
    ///   - velocity: 拖动结束时的速度
    ///   - completion: 完成回调
    func endDrag(velocity: CGFloat, completion: (() -> Void)? = nil) {
        guard case .dragging = state else { return }

        self.velocity = velocity
        self.completionHandler = completion
        self.isAnimating = true
        self.state = .animating

        // 根据进度和速度决定目标
        let threshold: CGFloat = 0.5
        let velocityThreshold: CGFloat = 0.5

        if currentProgress > threshold || velocity > velocityThreshold {
            targetProgress = 1.0
            direction = .forward
        } else if currentProgress < threshold || velocity < -velocityThreshold {
            targetProgress = 0.0
            direction = .backward
        } else {
            // 回弹到初始位置
            targetProgress = 0.0
            direction = .backward
        }

        startDisplayLink()
    }

    /// 取消翻页，回到初始位置
    func cancelPageTurn(completion: (() -> Void)? = nil) {
        self.completionHandler = completion
        self.isAnimating = true
        self.state = .animating
        targetProgress = 0.0
        direction = .backward

        startDisplayLink()
    }

    /// 重置引擎状态
    func reset() {
        stopAnimation()
        currentProgress = 0
        velocity = 0
        state = .idle
        initializeMesh()
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        stopDisplayLink()

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired))
        displayLink?.add(to: .main, forMode: .common)
        lastTimestamp = CACurrentMediaTime()
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    private func stopAnimation() {
        stopDisplayLink()
        isAnimating = false
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastTimestamp
        lastTimestamp = currentTime

        updatePhysics(deltaTime: deltaTime)
        updateMesh()

        // 检查是否完成
        if hasReachedTarget() {
            completeAnimation()
        }
    }

    // MARK: - Physics Simulation

    private func updatePhysics(deltaTime: TimeInterval) {
        let dt = CGFloat(min(deltaTime, 1.0 / 30.0)) // 限制最大 dt

        // 1. 计算重力影响
        let gravityForce = gravity * pageWeight * sin(currentProgress * .pi / 2) * 0.1

        // 2. 计算空气阻力 (与速度平方成正比，方向相反)
        let dragForce = -airResistance * velocity * abs(velocity) * 0.5

        // 3. 计算弹性恢复力
        let displacement = targetProgress - currentProgress
        let springForce = paperStiffness * displacement * 10

        // 4. 计算阻尼力
        let dampingForce = -elasticity * velocity * 2

        // 5. 总力和加速度
        let totalForce = gravityForce + dragForce + springForce + dampingForce
        let acceleration = totalForce / max(pageWeight, 0.1)

        // 6. Verlet 积分更新速度和位置
        velocity += acceleration * dt
        currentProgress += velocity * dt

        // 7. 边界处理
        if currentProgress <= 0 {
            currentProgress = 0
            velocity = abs(velocity) * elasticity * 0.3 // 弹性反弹
            if abs(velocity) < 0.01 { velocity = 0 }
        } else if currentProgress >= 1 {
            currentProgress = 1
            velocity = -abs(velocity) * elasticity * 0.3
            if abs(velocity) < 0.01 { velocity = 0 }
        }
    }

    private func hasReachedTarget() -> Bool {
        let progressDiff = abs(currentProgress - targetProgress)
        let isSlowEnough = abs(velocity) < 0.05
        let isCloseEnough = progressDiff < 0.01

        return isSlowEnough && isCloseEnough
    }

    private func completeAnimation() {
        stopDisplayLink()

        currentProgress = targetProgress
        velocity = 0
        isAnimating = false
        state = .completed

        // 回调完成
        let handler = completionHandler
        completionHandler = nil
        handler?()

        // 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.state = .idle
        }
    }

    // MARK: - Mesh Deformation

    private func updateMesh() {
        let progress = currentProgress

        for row in 0..<meshResolution {
            for col in 0..<meshResolution {
                let normalizedX = CGFloat(col) / CGFloat(meshResolution - 1)
                let normalizedY = CGFloat(row) / CGFloat(meshResolution - 1)

                // 计算卷曲变形
                let curlFactor = calculateCurlFactor(x: normalizedX, progress: progress)

                // 计算最终位置
                var newX = normalizedX
                var newY = normalizedY

                if direction == .forward {
                    // 从右向左翻页
                    let curve = sin(progress * .pi) * paperStiffness * 0.3
                    newX = normalizedX * (1 - progress) + (1 - normalizedX) * progress * curlFactor
                    newY = normalizedY + curve * (1 - normalizedX) * sin(normalizedY * .pi)
                } else {
                    // 从左向右翻页
                    let curve = sin((1 - progress) * .pi) * paperStiffness * 0.3
                    newX = normalizedX * progress + (normalizedX) * (1 - progress) * curlFactor
                    newY = normalizedY + curve * normalizedX * sin(normalizedY * .pi)
                }

                meshPoints[row][col] = CGPoint(x: newX, y: newY)
            }
        }
    }

    private func calculateCurlFactor(x: CGFloat, progress: CGFloat) -> CGFloat {
        // 使用贝塞尔曲线计算卷曲系数
        let t = progress
        let stiffnessEffect = (1 - paperStiffness) * 0.5 + 0.5

        // 卷曲从边缘开始
        let edgeDistance = direction == .forward ? (1 - x) : x
        let curlAmount = sin(edgeDistance * .pi * t) * stiffnessEffect

        return 1 - curlAmount * 0.5
    }
}

// MARK: - Mesh Renderer Helper

extension RealisticPageTurnEngine {
    /// 获取变形后的页面路径
    func getDeformedPath(for size: CGSize) -> Path {
        var path = Path()

        guard meshPoints.count >= 2 else { return path }

        // 使用贝塞尔曲线连接网格点
        let topPoints = meshPoints[0].map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let bottomPoints = meshPoints[meshResolution - 1].map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let leftPoints = meshPoints.map { $0[0] }.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let rightPoints = meshPoints.map { $0[meshResolution - 1] }.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }

        // 构建闭合路径
        if let first = topPoints.first {
            path.move(to: first)
        }

        // 顶边
        for point in topPoints.dropFirst() {
            path.addLine(to: point)
        }

        // 右边
        for point in rightPoints.dropFirst() {
            path.addLine(to: point)
        }

        // 底边（反向）
        for point in bottomPoints.reversed().dropFirst() {
            path.addLine(to: point)
        }

        // 左边（反向）
        for point in leftPoints.reversed().dropFirst() {
            path.addLine(to: point)
        }

        path.closeSubpath()

        return path
    }

    /// 获取阴影透明度
    var shadowOpacity: CGFloat {
        sin(currentProgress * .pi) * 0.5
    }

    /// 获取当前旋转角度（用于 3D 效果）
    var rotationAngle: Angle {
        Angle(degrees: Double(currentProgress) * direction.rotationAngle)
    }
}
