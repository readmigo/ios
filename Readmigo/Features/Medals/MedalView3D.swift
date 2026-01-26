import SwiftUI
import SceneKit

// MARK: - Medal View 3D

struct MedalView3D: View {
    let medal: Medal
    let size: MedalSize
    var isUnlocked: Bool = true
    var autoRotate: Bool = true

    enum MedalSize {
        case small      // 40pt - List items
        case medium     // 80pt - Grid
        case large      // 160pt - Detail display
        case showcase   // Full screen showcase

        var frameSize: CGSize {
            switch self {
            case .small: return CGSize(width: 40, height: 40)
            case .medium: return CGSize(width: 80, height: 80)
            case .large: return CGSize(width: 160, height: 160)
            case .showcase: return CGSize(width: 300, height: 300)
            }
        }
    }

    @State private var scene: SCNScene?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let scene = scene {
                SceneView(
                    scene: scene,
                    options: autoRotate ? [.autoenablesDefaultLighting] : [.autoenablesDefaultLighting, .allowsCameraControl]
                )
                .frame(width: size.frameSize.width, height: size.frameSize.height)
            } else {
                // Fallback 2D view while loading
                MedalPlaceholder(medal: medal, size: size, isUnlocked: isUnlocked)
            }

            // Legendary glow effect
            if isUnlocked && medal.rarity == .legendary {
                RadialGradient(
                    gradient: Gradient(colors: [
                        medal.rarity.glowColor,
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: size.frameSize.width * 0.3,
                    endRadius: size.frameSize.width * 0.6
                )
                .frame(width: size.frameSize.width * 1.5, height: size.frameSize.height * 1.5)
                .allowsHitTesting(false)
            }

            // Lock overlay
            if !isUnlocked {
                Circle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: size.frameSize.width * 0.8, height: size.frameSize.height * 0.8)

                Image(systemName: "lock.fill")
                    .font(.system(size: size.frameSize.width * 0.2))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .onAppear {
            loadScene()
        }
    }

    private func loadScene() {
        Task {
            scene = await MedalSceneBuilder.build(for: medal, autoRotate: autoRotate)
            isLoading = false
        }
    }
}

// MARK: - Medal Placeholder (2D Fallback)

struct MedalPlaceholder: View {
    let medal: Medal
    let size: MedalView3D.MedalSize
    var isUnlocked: Bool = true

    var body: some View {
        ZStack {
            // Medal circle
            Circle()
                .fill(medal.rarity.gradient)
                .frame(width: size.frameSize.width * 0.8, height: size.frameSize.height * 0.8)
                .shadow(color: medal.rarity.color.opacity(0.3), radius: 5)

            // Inner highlight
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: size.frameSize.width * 0.8, height: size.frameSize.height * 0.8)

            // Icon
            Image(systemName: medal.category.icon)
                .font(.system(size: size.frameSize.width * 0.35))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Medal Scene Builder

class MedalSceneBuilder {

    static func build(for medal: Medal, autoRotate: Bool) async -> SCNScene {
        let scene = SCNScene()

        // Create medal geometry
        let medalNode = createMedalNode(for: medal)
        scene.rootNode.addChildNode(medalNode)

        // Add lighting
        setupLighting(in: scene)

        // Add camera
        setupCamera(in: scene)

        // Add rotation animation if enabled
        if autoRotate {
            addRotationAnimation(to: medalNode)
        }

        // Add floating animation
        addFloatingAnimation(to: medalNode)

        return scene
    }

    private static func createMedalNode(for medal: Medal) -> SCNNode {
        // Create medal geometry (cylinder for 3D coin-like shape)
        let cylinder = SCNCylinder(radius: 1.0, height: 0.15)
        cylinder.radialSegmentCount = 64

        // Apply material based on rarity
        cylinder.materials = [createMaterial(for: medal.rarity)]

        let node = SCNNode(geometry: cylinder)
        node.eulerAngles.x = Float.pi / 2  // Rotate to face camera

        // Add center emblem
        let emblemNode = createEmblemNode(for: medal)
        node.addChildNode(emblemNode)

        return node
    }

    private static func createMaterial(for rarity: MedalRarity) -> SCNMaterial {
        let material = SCNMaterial()

        switch rarity {
        case .common:
            // Copper
            material.diffuse.contents = UIColor(hex: "#B87333")
            material.metalness.contents = 0.85
            material.roughness.contents = 0.35
            material.specular.contents = UIColor.white
            material.specular.intensity = 0.6

        case .uncommon:
            // Silver
            material.diffuse.contents = UIColor(hex: "#C0C0C0")
            material.metalness.contents = 0.95
            material.roughness.contents = 0.15
            material.specular.contents = UIColor.white
            material.specular.intensity = 0.9

        case .rare:
            // Gold
            material.diffuse.contents = UIColor(hex: "#FFD700")
            material.metalness.contents = 1.0
            material.roughness.contents = 0.1
            material.specular.contents = UIColor.white
            material.specular.intensity = 1.0

        case .epic:
            // Platinum with purple tint
            material.diffuse.contents = UIColor(hex: "#E5E4E2")
            material.metalness.contents = 1.0
            material.roughness.contents = 0.05
            material.specular.contents = UIColor(hex: "#9B5DE5")
            material.specular.intensity = 1.2
            material.emission.contents = UIColor(hex: "#9B5DE5").withAlphaComponent(0.1)

        case .legendary:
            // Diamond effect
            material.diffuse.contents = UIColor(hex: "#B9F2FF")
            material.metalness.contents = 1.0
            material.roughness.contents = 0.0
            material.specular.contents = UIColor.white
            material.specular.intensity = 1.5
            material.emission.contents = UIColor(hex: "#00BBF9").withAlphaComponent(0.2)
            material.transparent.contents = UIColor.white.withAlphaComponent(0.9)
            material.transparency = 0.1
        }

        material.lightingModel = .physicallyBased
        material.fresnelExponent = 1.0

        return material
    }

    private static func createEmblemNode(for medal: Medal) -> SCNNode {
        // Create a flat circle for the emblem
        let emblem = SCNPlane(width: 1.4, height: 1.4)

        let emblemMaterial = SCNMaterial()
        emblemMaterial.diffuse.contents = UIColor.white.withAlphaComponent(0.3)
        emblemMaterial.emission.contents = UIColor.white.withAlphaComponent(0.1)
        emblem.materials = [emblemMaterial]

        let node = SCNNode(geometry: emblem)
        node.position = SCNVector3(0, 0.08, 0)
        node.eulerAngles.x = -Float.pi / 2

        return node
    }

    private static func setupLighting(in scene: SCNScene) {
        // Key light (warm white)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor(hex: "#FFF8E7")
        keyLight.light?.intensity = 1000
        keyLight.light?.castsShadow = true
        keyLight.position = SCNVector3(5, 5, 5)
        keyLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyLight)

        // Fill light (cool blue)
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .directional
        fillLight.light?.color = UIColor(hex: "#E3F2FD")
        fillLight.light?.intensity = 400
        fillLight.position = SCNVector3(-3, 3, 3)
        scene.rootNode.addChildNode(fillLight)

        // Rim light (white)
        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .directional
        rimLight.light?.color = UIColor.white
        rimLight.light?.intensity = 600
        rimLight.position = SCNVector3(0, -2, -5)
        scene.rootNode.addChildNode(rimLight)

        // Ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.color = UIColor.gray
        ambientLight.light?.intensity = 200
        scene.rootNode.addChildNode(ambientLight)
    }

    private static func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 45
        cameraNode.position = SCNVector3(0, 0, 4)
        scene.rootNode.addChildNode(cameraNode)
    }

    private static func addRotationAnimation(to node: SCNNode) {
        let rotation = CABasicAnimation(keyPath: "eulerAngles.y")
        rotation.fromValue = 0
        rotation.toValue = Float.pi * 2
        rotation.duration = 10
        rotation.repeatCount = .infinity
        node.addAnimation(rotation, forKey: "rotate")
    }

    private static func addFloatingAnimation(to node: SCNNode) {
        let float = CABasicAnimation(keyPath: "position.y")
        float.fromValue = 0
        float.toValue = 0.1
        float.duration = 2
        float.autoreverses = true
        float.repeatCount = .infinity
        float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(float, forKey: "float")
    }
}

// MARK: - Medal 3D Showcase View

struct MedalShowcaseView: View {
    let medal: Medal
    @State private var isRotating = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(hex: "#1a1a2e"),
                    Color(hex: "#16213e"),
                    Color(hex: "#0f3460")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // 3D Medal
                MedalView3D(medal: medal, size: .showcase, autoRotate: true)
                    .frame(height: 300)

                // Medal info
                VStack(spacing: 16) {
                    Text(medal.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Circle()
                            .fill(medal.rarity.color)
                            .frame(width: 12, height: 12)
                        Text(medal.rarity.displayName)
                            .font(.headline)
                            .foregroundColor(medal.rarity.color)
                        Text("•")
                            .foregroundColor(.white.opacity(0.5))
                        Text(medal.rarity.materialName)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text(medal.localizedDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
    }
}
