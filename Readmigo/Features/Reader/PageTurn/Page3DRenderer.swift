import SwiftUI
import simd

// MARK: - Page 3D Renderer

/// 页面 3D 渲染器 - 实现光影效果
class Page3DRenderer: ObservableObject {

    // MARK: - Light Properties

    /// 光源位置
    @Published var lightPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 100)

    /// 环境光强度 (0-1)
    @Published var ambientLight: Float = 0.3

    /// 漫反射光强度 (0-1)
    @Published var diffuseLight: Float = 0.7

    /// 镜面高光强度 (0-1)
    @Published var specularLight: Float = 0.5

    /// 高光锐度
    @Published var shininess: Float = 32.0

    // MARK: - Shadow Properties

    /// 阴影启用
    @Published var shadowEnabled: Bool = true

    /// 阴影颜色
    @Published var shadowColor: Color = .black

    /// 阴影透明度
    @Published var shadowOpacity: Float = 0.3

    /// 阴影模糊半径
    @Published var shadowBlur: CGFloat = 20

    /// 阴影偏移
    @Published var shadowOffset: CGSize = CGSize(width: 5, height: 10)

    // MARK: - Paper Properties

    /// 纸张颜色
    @Published var paperColor: Color = .white

    /// 纸张纹理透明度
    @Published var paperTextureOpacity: Float = 0.1

    // MARK: - Computed Properties

    /// 计算给定法向量的光照强度
    func calculateLighting(normal: SIMD3<Float>, viewDirection: SIMD3<Float>) -> Float {
        // 归一化向量
        let N = normalize(normal)
        let V = normalize(viewDirection)
        let L = normalize(lightPosition)

        // Phong 光照模型

        // 1. 环境光
        let ambient = ambientLight

        // 2. 漫反射 (Lambert)
        let NdotL = max(dot(N, L), 0.0)
        let diffuse = diffuseLight * NdotL

        // 3. 镜面高光 (Blinn-Phong)
        let H = normalize(L + V) // 半角向量
        let NdotH = max(dot(N, H), 0.0)
        let specular = specularLight * pow(NdotH, shininess)

        return min(ambient + diffuse + specular, 1.0)
    }

    /// 根据翻页进度计算阴影参数
    func calculateShadow(progress: CGFloat) -> PageShadow {
        let shadowProgress = sin(progress * .pi) // 在中间最大

        return PageShadow(
            color: shadowColor.opacity(Double(shadowOpacity) * Double(shadowProgress)),
            blur: shadowBlur * shadowProgress,
            offset: CGSize(
                width: shadowOffset.width * shadowProgress,
                height: shadowOffset.height * shadowProgress
            )
        )
    }

    /// 计算页面渐变（模拟光照效果）
    func calculateGradient(progress: CGFloat, isBackSide: Bool) -> LinearGradient {
        let lightIntensity = 1.0 - sin(progress * .pi) * 0.3

        if isBackSide {
            // 背面较暗
            return LinearGradient(
                colors: [
                    Color.white.opacity(lightIntensity * 0.8),
                    Color.white.opacity(lightIntensity * 0.6)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // 正面
            return LinearGradient(
                colors: [
                    Color.white.opacity(lightIntensity),
                    Color.white.opacity(lightIntensity * 0.9)
                ],
                startPoint: .trailing,
                endPoint: .leading
            )
        }
    }
}

// MARK: - Page Shadow

struct PageShadow {
    let color: Color
    let blur: CGFloat
    let offset: CGSize
}

// MARK: - Page Curl Effect View

struct PageCurlEffectView: View {
    let progress: CGFloat
    let direction: PageTurnDirection
    let frontContent: AnyView
    let backContent: AnyView?
    let size: CGSize

    @StateObject private var renderer = Page3DRenderer()

    var body: some View {
        ZStack {
            // 底层阴影
            if renderer.shadowEnabled {
                shadowLayer
            }

            // 页面层
            pageLayer
        }
    }

    private var shadowLayer: some View {
        let shadow = renderer.calculateShadow(progress: progress)
        return RoundedRectangle(cornerRadius: 4)
            .fill(shadow.color)
            .blur(radius: shadow.blur)
            .offset(shadow.offset)
            .opacity(Double(progress))
    }

    private var pageLayer: some View {
        GeometryReader { geometry in
            ZStack {
                // 正面
                frontContent
                    .opacity(progress < 0.5 ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(Double(progress) * (direction == .forward ? -180 : 180)),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: direction == .forward ? .trailing : .leading,
                        perspective: 0.5
                    )

                // 背面
                if let back = backContent {
                    back
                        .opacity(progress >= 0.5 ? 1 : 0)
                        .rotation3DEffect(
                            .degrees(Double(progress - 1) * (direction == .forward ? -180 : 180)),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: direction == .forward ? .trailing : .leading,
                            perspective: 0.5
                        )
                }

                // 光照渐变层
                lightingOverlay
            }
        }
    }

    private var lightingOverlay: some View {
        let gradient = renderer.calculateGradient(progress: progress, isBackSide: progress >= 0.5)
        return Rectangle()
            .fill(gradient)
            .blendMode(.overlay)
            .opacity(0.3)
    }
}

// MARK: - Realistic Page Turn View

struct RealisticPageTurnView<Content: View>: View {
    @ObservedObject var engine: RealisticPageTurnEngine
    let content: () -> Content

    @StateObject private var renderer = Page3DRenderer()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 阴影层
                shadowLayer(size: geometry.size)

                // 页面内容层
                contentLayer(size: geometry.size)
            }
        }
    }

    @ViewBuilder
    private func shadowLayer(size: CGSize) -> some View {
        if renderer.shadowEnabled && engine.isAnimating {
            let shadow = renderer.calculateShadow(progress: engine.currentProgress)
            engine.getDeformedPath(for: size)
                .fill(shadow.color)
                .blur(radius: shadow.blur)
                .offset(shadow.offset)
        }
    }

    private func contentLayer(size: CGSize) -> some View {
        content()
            .clipShape(engine.getDeformedPath(for: size))
            .overlay(
                lightingOverlay
            )
    }

    private var lightingOverlay: some View {
        let gradient = renderer.calculateGradient(
            progress: engine.currentProgress,
            isBackSide: false
        )
        return Rectangle()
            .fill(gradient)
            .blendMode(.overlay)
            .opacity(engine.isAnimating ? 0.2 : 0)
            .allowsHitTesting(false)
    }
}

// MARK: - Page Flip 3D Effect

struct PageFlip3DEffect: ViewModifier {
    let progress: CGFloat
    let direction: PageTurnDirection
    let perspective: CGFloat

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(progress) * direction.rotationAngle),
                axis: (x: 0, y: 1, z: 0),
                anchor: direction == .forward ? .trailing : .leading,
                anchorZ: 0,
                perspective: perspective
            )
    }
}

// MARK: - Cube Effect

struct CubePageEffect: ViewModifier {
    let progress: CGFloat
    let direction: PageTurnDirection

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(Double(progress) * (direction == .forward ? -90 : 90)),
                axis: (x: 0, y: 1, z: 0),
                anchor: direction == .forward ? .trailing : .leading,
                perspective: 0.5
            )
            .opacity(1 - Double(progress) * 0.5)
    }
}

// MARK: - View Extensions

extension View {
    func pageFlip3D(progress: CGFloat, direction: PageTurnDirection, perspective: CGFloat = 0.5) -> some View {
        modifier(PageFlip3DEffect(progress: progress, direction: direction, perspective: perspective))
    }

    func cubePageEffect(progress: CGFloat, direction: PageTurnDirection) -> some View {
        modifier(CubePageEffect(progress: progress, direction: direction))
    }
}
