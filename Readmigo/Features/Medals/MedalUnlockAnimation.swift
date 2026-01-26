import SwiftUI

// MARK: - Medal Unlock Overlay

struct MedalUnlockOverlay: View {
    @StateObject private var manager = MedalManager.shared
    @State private var currentMedal: UserMedal?
    @State private var showAnimation = false

    var body: some View {
        ZStack {
            if showAnimation, let medal = currentMedal {
                MedalUnlockAnimationView(
                    medal: medal.medal,
                    onDismiss: {
                        dismissCurrentMedal()
                    }
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .medalUnlocked)) { notification in
            if let userMedal = notification.object as? UserMedal {
                showMedalUnlock(userMedal)
            }
        }
    }

    private func showMedalUnlock(_ userMedal: UserMedal) {
        currentMedal = userMedal
        withAnimation(.easeOut(duration: 0.3)) {
            showAnimation = true
        }
    }

    private func dismissCurrentMedal() {
        withAnimation(.easeIn(duration: 0.3)) {
            showAnimation = false
        }

        if let medal = currentMedal {
            manager.clearNewlyUnlocked(medal.medalId)
        }
        currentMedal = nil
    }
}

// MARK: - Medal Unlock Animation View

struct MedalUnlockAnimationView: View {
    let medal: Medal
    let onDismiss: () -> Void

    @State private var phase: AnimationPhase = .initial
    @State private var particleSystem = ParticleSystem()

    enum AnimationPhase {
        case initial
        case flyIn
        case bounce
        case stable
        case particles
        case complete
    }

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(backgroundOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    if phase == .complete {
                        onDismiss()
                    }
                }

            VStack(spacing: 32) {
                Spacer()

                // Medal display
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [medal.rarity.glowColor, Color.clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: glowRadius
                            )
                        )
                        .frame(width: 300, height: 300)
                        .opacity(glowOpacity)

                    // Particle effects
                    ForEach(particleSystem.particles) { particle in
                        Circle()
                            .fill(particle.color)
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: particle.x, y: particle.y)
                            .opacity(particle.opacity)
                    }

                    // Medal
                    ZStack {
                        Circle()
                            .fill(medal.rarity.gradient)
                            .frame(width: medalSize, height: medalSize)
                            .shadow(color: medal.rarity.color.opacity(0.5), radius: 20, x: 0, y: 10)

                        // Inner highlight
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .frame(width: medalSize, height: medalSize)

                        // Icon
                        Image(systemName: medal.category.icon)
                            .font(.system(size: iconSize))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(medalScale)
                    .offset(y: medalOffset)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                }

                // Text content
                VStack(spacing: 16) {
                    Text("medal.unlocked".localized)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))

                    Text(medal.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Rarity badge
                    HStack(spacing: 8) {
                        Circle()
                            .fill(medal.rarity.color)
                            .frame(width: 12, height: 12)
                        Text(medal.rarity.displayName)
                            .font(.headline)
                            .foregroundColor(medal.rarity.color)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)

                    Text(medal.localizedDescription)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(textOpacity)

                Spacer()

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text("common.continue".localized)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(medal.rarity.gradient)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .opacity(buttonOpacity)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Animation Properties

    private var backgroundOpacity: Double {
        switch phase {
        case .initial: return 0
        case .flyIn, .bounce, .stable, .particles, .complete: return 0.85
        }
    }

    private var medalSize: CGFloat {
        switch phase {
        case .initial: return 20
        case .flyIn: return 160
        case .bounce: return 140
        case .stable, .particles, .complete: return 150
        }
    }

    private var medalScale: CGFloat {
        switch phase {
        case .initial: return 0.1
        case .flyIn: return 1.2
        case .bounce: return 0.95
        case .stable, .particles, .complete: return 1.0
        }
    }

    private var medalOffset: CGFloat {
        switch phase {
        case .initial: return 500
        case .flyIn, .bounce, .stable, .particles, .complete: return 0
        }
    }

    private var iconSize: CGFloat {
        switch phase {
        case .initial: return 10
        case .flyIn: return 70
        case .bounce: return 60
        case .stable, .particles, .complete: return 65
        }
    }

    private var glowRadius: CGFloat {
        switch phase {
        case .initial, .flyIn: return 60
        case .bounce, .stable: return 120
        case .particles, .complete: return 140
        }
    }

    private var glowOpacity: Double {
        switch phase {
        case .initial: return 0
        case .flyIn: return 0.3
        case .bounce, .stable: return 0.6
        case .particles, .complete: return 0.8
        }
    }

    private var rotation: Double {
        switch phase {
        case .initial, .flyIn, .bounce: return 0
        case .stable: return 15
        case .particles: return -15
        case .complete: return 0
        }
    }

    private var textOpacity: Double {
        switch phase {
        case .initial, .flyIn, .bounce: return 0
        case .stable, .particles, .complete: return 1
        }
    }

    private var buttonOpacity: Double {
        switch phase {
        case .initial, .flyIn, .bounce, .stable, .particles: return 0
        case .complete: return 1
        }
    }

    // MARK: - Animation Sequence

    private func startAnimation() {
        // Phase 1: Fly in
        withAnimation(.easeOut(duration: 0.5)) {
            phase = .flyIn
        }

        // Phase 2: Bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = .bounce
            }
        }

        // Phase 3: Stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .stable
            }
        }

        // Phase 4: Particles (for Epic and Legendary)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if medal.rarity == .epic || medal.rarity == .legendary {
                startParticles()
            }
            withAnimation(.easeInOut(duration: 0.5)) {
                phase = .particles
            }
        }

        // Phase 5: Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                phase = .complete
            }
        }
    }

    private func startParticles() {
        particleSystem.emit(count: medal.rarity == .legendary ? 50 : 30, color: medal.rarity.color)
    }
}

// MARK: - Particle System

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var color: Color
        var opacity: Double
        var velocity: CGPoint
    }

    func emit(count: Int, color: Color) {
        for _ in 0..<count {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 100...200)
            let particle = Particle(
                x: 0,
                y: 0,
                size: CGFloat.random(in: 2...8),
                color: [color, .white, .yellow].randomElement()!,
                opacity: 1.0,
                velocity: CGPoint(
                    x: cos(angle) * speed,
                    y: sin(angle) * speed
                )
            )
            particles.append(particle)
        }

        // Animate particles
        animateParticles()
    }

    private func animateParticles() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if self.particles.isEmpty {
                timer.invalidate()
                return
            }

            for i in self.particles.indices.reversed() {
                self.particles[i].x += self.particles[i].velocity.x * 0.016
                self.particles[i].y += self.particles[i].velocity.y * 0.016
                self.particles[i].velocity.y += 200 * 0.016 // Gravity
                self.particles[i].opacity -= 0.02

                if self.particles[i].opacity <= 0 {
                    self.particles.remove(at: i)
                }
            }
        }
        RunLoop.current.add(timer, forMode: .common)
    }
}

// MARK: - Confetti Effect

struct ConfettiView: View {
    let colors: [Color]
    @State private var confetti: [ConfettiPiece] = []

    struct ConfettiPiece: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var color: Color
        var size: CGFloat
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(confetti) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.5)
                        .rotationEffect(.degrees(piece.rotation))
                        .position(x: piece.x, y: piece.y)
                }
            }
            .onAppear {
                startConfetti(in: geometry.size)
            }
        }
    }

    private func startConfetti(in size: CGSize) {
        for _ in 0..<100 {
            let piece = ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: -20,
                rotation: Double.random(in: 0...360),
                color: colors.randomElement() ?? .yellow,
                size: CGFloat.random(in: 6...12)
            )
            confetti.append(piece)
        }

        // Animate falling
        withAnimation(.linear(duration: 3)) {
            for i in confetti.indices {
                confetti[i].y = size.height + 50
                confetti[i].rotation += Double.random(in: 360...720)
            }
        }
    }
}
