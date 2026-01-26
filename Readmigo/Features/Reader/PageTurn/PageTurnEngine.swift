import SwiftUI
import Combine

// MARK: - Page Turn Engine

/// 物理级翻页动画系统 - 统一协调器
/// 整合物理模拟、3D渲染、声效和触觉反馈
@MainActor
class PageTurnEngine: ObservableObject {

    // MARK: - Sub-engines

    /// 物理模拟引擎
    let physicsEngine: RealisticPageTurnEngine

    /// 3D 渲染器
    let renderer: Page3DRenderer

    /// 声效引擎
    let soundEngine: PageTurnSoundEngine

    /// 触觉引擎
    let hapticEngine: PageTurnHapticEngine

    // MARK: - Settings

    /// 设置管理器
    @Published var settings: PageTurnSettings {
        didSet {
            applySettings()
        }
    }

    // MARK: - State

    /// 当前页码
    @Published private(set) var currentPage: Int = 0

    /// 总页数
    @Published var totalPages: Int = 1

    /// 是否正在翻页
    @Published private(set) var isTurning: Bool = false

    /// 翻页方向
    @Published private(set) var direction: PageTurnDirection = .forward

    /// 翻页进度 (0-1)
    @Published private(set) var progress: CGFloat = 0

    // MARK: - Callbacks

    var onPageChange: ((Int) -> Void)?
    var onReachStart: (() -> Void)?
    var onReachEnd: (() -> Void)?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var autoPageTimer: Timer?

    // MARK: - Initialization

    init(settings: PageTurnSettings = .default) {
        self.settings = settings
        self.physicsEngine = RealisticPageTurnEngine()
        self.renderer = Page3DRenderer()
        self.soundEngine = PageTurnSoundEngine()
        self.hapticEngine = PageTurnHapticEngine()

        setupBindings()
        applySettings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // 监听物理引擎状态变化
        physicsEngine.$currentProgress
            .sink { [weak self] progress in
                self?.progress = progress
            }
            .store(in: &cancellables)

        physicsEngine.$isAnimating
            .sink { [weak self] isAnimating in
                self?.isTurning = isAnimating
            }
            .store(in: &cancellables)

        physicsEngine.$direction
            .sink { [weak self] direction in
                self?.direction = direction
            }
            .store(in: &cancellables)
    }

    private func applySettings() {
        // 应用物理参数
        physicsEngine.paperStiffness = settings.paperStiffness

        // 应用声效设置
        soundEngine.isEnabled = settings.enableSound
        soundEngine.volume = settings.soundVolume

        // 应用触觉设置
        hapticEngine.isEnabled = settings.enableHaptic
        hapticEngine.intensity = settings.hapticIntensity

        // 应用渲染设置
        renderer.shadowEnabled = settings.enableShadow

        // 处理自动翻页
        if settings.autoPageEnabled {
            startAutoPage()
        } else {
            stopAutoPage()
        }
    }

    // MARK: - Public Methods

    /// 翻到下一页
    /// - Parameter animated: 是否使用动画
    func goToNextPage(animated: Bool = true) {
        guard currentPage < totalPages - 1 else {
            onReachEnd?()
            return
        }

        if animated && settings.mode.hasPhysics {
            performPhysicsPageTurn(direction: .forward)
        } else {
            performSimplePageTurn(direction: .forward)
        }
    }

    /// 翻到上一页
    /// - Parameter animated: 是否使用动画
    func goToPreviousPage(animated: Bool = true) {
        guard currentPage > 0 else {
            onReachStart?()
            return
        }

        if animated && settings.mode.hasPhysics {
            performPhysicsPageTurn(direction: .backward)
        } else {
            performSimplePageTurn(direction: .backward)
        }
    }

    /// 跳转到指定页
    /// - Parameters:
    ///   - page: 目标页码
    ///   - animated: 是否使用动画
    func goToPage(_ page: Int, animated: Bool = true) {
        guard page >= 0 && page < totalPages else { return }
        guard page != currentPage else { return }

        let direction: PageTurnDirection = page > currentPage ? .forward : .backward

        if animated {
            performSimplePageTurn(direction: direction) { [weak self] in
                self?.currentPage = page
            }
        } else {
            currentPage = page
            onPageChange?(currentPage)
        }
    }

    /// 开始拖动翻页
    /// - Parameter startX: 起始 X 坐标
    func beginDrag(at startX: CGFloat) {
        stopAutoPage()
        physicsEngine.beginDrag(at: 0)

        // 开始连续触觉
        if settings.enableHaptic {
            hapticEngine.startContinuousHaptic(intensity: 0.1)
        }

        // 播放开始翻页的触觉
        hapticEngine.playPageLiftHaptic()
    }

    /// 更新拖动进度
    /// - Parameters:
    ///   - currentX: 当前 X 坐标
    ///   - startX: 起始 X 坐标
    ///   - screenWidth: 屏幕宽度
    func updateDrag(currentX: CGFloat, startX: CGFloat, screenWidth: CGFloat) {
        let offset = currentX - startX
        let progress = abs(offset) / screenWidth

        physicsEngine.updateDrag(to: progress)

        // 更新触觉强度
        if settings.enableHaptic {
            hapticEngine.updateContinuousHaptic(intensity: Float(progress) * 0.3)
        }

        // 播放实时摩擦声
        if settings.enableSound {
            soundEngine.playRealtimeRustle(intensity: progress)
        }
    }

    /// 结束拖动
    /// - Parameters:
    ///   - velocity: 拖动速度
    ///   - direction: 拖动方向
    func endDrag(velocity: CGFloat, direction: PageTurnDirection) {
        soundEngine.stopRustle()
        hapticEngine.stopContinuousHaptic()

        let threshold: CGFloat = 0.3
        let velocityThreshold: CGFloat = 500

        let shouldComplete = progress > threshold || abs(velocity) > velocityThreshold

        if shouldComplete {
            physicsEngine.endDrag(velocity: velocity / 1000) { [weak self] in
                self?.completePageTurn(direction: direction)
            }
        } else {
            physicsEngine.cancelPageTurn { [weak self] in
                self?.hapticEngine.playPageDropHaptic()
            }
        }
    }

    /// 取消翻页
    func cancelPageTurn() {
        soundEngine.stopRustle()
        hapticEngine.stopContinuousHaptic()
        physicsEngine.cancelPageTurn()

        if settings.autoPageEnabled {
            startAutoPage()
        }
    }

    /// 重置引擎
    func reset() {
        stopAutoPage()
        physicsEngine.reset()
        currentPage = 0
        totalPages = 1
    }

    // MARK: - Auto Page

    /// 开始自动翻页
    func startAutoPage() {
        stopAutoPage()

        guard settings.autoPageEnabled else { return }

        autoPageTimer = Timer.scheduledTimer(withTimeInterval: settings.autoPageInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.goToNextPage()
            }
        }
    }

    /// 停止自动翻页
    func stopAutoPage() {
        autoPageTimer?.invalidate()
        autoPageTimer = nil
    }

    // MARK: - Private Methods

    private func performPhysicsPageTurn(direction: PageTurnDirection) {
        guard !isTurning else { return }

        // 播放开始触觉
        hapticEngine.playPageLiftHaptic()

        physicsEngine.startPageTurn(direction: direction) { [weak self] in
            self?.completePageTurn(direction: direction)
        }
    }

    private func performSimplePageTurn(direction: PageTurnDirection, completion: (() -> Void)? = nil) {
        guard !isTurning else { return }

        isTurning = true
        self.direction = direction

        // 使用简单动画
        withAnimation(.easeInOut(duration: settings.adjustedDuration)) {
            progress = 1.0
        }

        // 播放音效和触觉
        if settings.enableSound {
            soundEngine.playPageTurnSound(velocity: 1.0)
        }
        if settings.enableHaptic {
            hapticEngine.playPageTurnHaptic()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + settings.adjustedDuration) { [weak self] in
            guard let self = self else { return }

            self.progress = 0
            self.isTurning = false

            if direction == .forward {
                self.currentPage += 1
            } else {
                self.currentPage -= 1
            }

            self.onPageChange?(self.currentPage)
            completion?()
        }
    }

    private func completePageTurn(direction: PageTurnDirection) {
        // 更新页码
        if direction == .forward {
            currentPage = min(currentPage + 1, totalPages - 1)
        } else {
            currentPage = max(currentPage - 1, 0)
        }

        // 播放完成音效
        if settings.enableSound {
            soundEngine.playPageTurnSound(velocity: physicsEngine.velocity)
        }

        // 播放完成触觉
        hapticEngine.playPageDropHaptic()

        // 回调
        onPageChange?(currentPage)

        // 重新启动自动翻页
        if settings.autoPageEnabled {
            startAutoPage()
        }
    }
}

// MARK: - Page Turn Container View

/// 翻页容器视图 - 处理手势和动画
struct PageTurnContainerView<Content: View>: View {
    @ObservedObject var engine: PageTurnEngine
    let content: (Int) -> Content

    @State private var dragStartX: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 当前页面
                currentPageView(size: geometry.size)

                // 翻页动画层
                if engine.isTurning || isDragging {
                    turningPageView(size: geometry.size)
                }
            }
            .contentShape(Rectangle())
            .gesture(pageTurnGesture(screenWidth: geometry.size.width))
        }
    }

    @ViewBuilder
    private func currentPageView(size: CGSize) -> some View {
        content(engine.currentPage)
            .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func turningPageView(size: CGSize) -> some View {
        switch engine.settings.mode {
        case .realistic, .pageCurl:
            RealisticPageTurnView(engine: engine.physicsEngine) {
                content(nextPageIndex)
            }

        case .flip:
            content(nextPageIndex)
                .pageFlip3D(progress: engine.progress, direction: engine.direction)

        case .cube:
            content(nextPageIndex)
                .cubePageEffect(progress: engine.progress, direction: engine.direction)

        case .slide:
            slideEffect(size: size)

        case .fade:
            fadeEffect

        case .cover:
            coverEffect(size: size)

        case .accordion:
            accordionEffect(size: size)

        default:
            EmptyView()
        }
    }

    private var nextPageIndex: Int {
        engine.direction == .forward
            ? min(engine.currentPage + 1, engine.totalPages - 1)
            : max(engine.currentPage - 1, 0)
    }

    @ViewBuilder
    private func slideEffect(size: CGSize) -> some View {
        let offset = engine.direction == .forward
            ? size.width * (1 - engine.progress)
            : -size.width * (1 - engine.progress)

        content(nextPageIndex)
            .offset(x: offset)
    }

    private var fadeEffect: some View {
        content(nextPageIndex)
            .opacity(Double(engine.progress))
    }

    @ViewBuilder
    private func coverEffect(size: CGSize) -> some View {
        let offset = engine.direction == .forward
            ? size.width * (1 - engine.progress)
            : -size.width * (1 - engine.progress)

        content(nextPageIndex)
            .offset(x: offset)
            .shadow(radius: 10 * engine.progress)
    }

    @ViewBuilder
    private func accordionEffect(size: CGSize) -> some View {
        content(nextPageIndex)
            .scaleEffect(x: engine.progress, y: 1, anchor: engine.direction == .forward ? .leading : .trailing)
    }

    private func pageTurnGesture(screenWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    dragStartX = value.startLocation.x
                    engine.beginDrag(at: dragStartX)
                }

                engine.updateDrag(
                    currentX: value.location.x,
                    startX: dragStartX,
                    screenWidth: screenWidth
                )
            }
            .onEnded { value in
                isDragging = false

                let velocity = value.predictedEndLocation.x - value.location.x
                let direction: PageTurnDirection = velocity < 0 ? .forward : .backward

                engine.endDrag(velocity: velocity, direction: direction)
            }
    }
}
