import SwiftUI

// MARK: - Reading Progress View (Industry-leading progress visualization)

struct ReadingProgressView: View {
    let progress: Double // 0-1
    let chapterProgress: Double // 0-1 within current chapter
    let totalChapters: Int
    let currentChapter: Int
    let estimatedTimeRemaining: Int // minutes
    let wordsRead: Int
    let readingSpeed: Int // words per minute

    @State private var animatedProgress: Double = 0
    @State private var showDetails = false
    @State private var pulseAnimation = false

    var body: some View {
        VStack(spacing: 0) {
            // Main progress bar with glow effect
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)

                // Progress fill with gradient
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, CGFloat(animatedProgress) * UIScreen.main.bounds.width - 40), height: 4)
                    .shadow(color: .purple.opacity(0.5), radius: pulseAnimation ? 8 : 4)

                // Progress indicator dot
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .purple.opacity(0.5), radius: 4)
                    .offset(x: max(0, CGFloat(animatedProgress) * (UIScreen.main.bounds.width - 52)))
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
            }
            .padding(.horizontal, 20)
            .onTapGesture {
                withAnimation(.spring(response: 0.3)) {
                    showDetails.toggle()
                }
            }

            // Detailed stats (expandable)
            if showDetails {
                HStack(spacing: 20) {
                    StatItem(
                        icon: "book.pages",
                        value: "\(Int(progress * 100))%",
                        label: "Complete"
                    )

                    StatItem(
                        icon: "clock",
                        value: formatTime(estimatedTimeRemaining),
                        label: "Remaining"
                    )

                    StatItem(
                        icon: "text.word.spacing",
                        value: "\(wordsRead)",
                        label: "Words"
                    )

                    StatItem(
                        icon: "speedometer",
                        value: "\(readingSpeed)",
                        label: "WPM"
                    )
                }
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }

    private func formatTime(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }
}

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Chapter Progress Ring

struct ChapterProgressRing: View {
    let progress: Double
    let chapterNumber: Int
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            // Progress arc
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [.blue, .purple, .pink, .blue],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Chapter number
            VStack(spacing: 0) {
                Text("Ch")
                    .font(.system(size: size * 0.15))
                    .foregroundColor(.secondary)
                Text("\(chapterNumber)")
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Milestone Celebration View

struct MilestoneCelebrationView: View {
    let milestone: ReadingMilestone
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var particleSystem = ParticleSystem()

    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            // Particles
            ParticleView(system: particleSystem)
                .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                // Icon with glow
                ZStack {
                    Circle()
                        .fill(milestone.color.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    Image(systemName: milestone.icon)
                        .font(.system(size: 60))
                        .foregroundStyle(milestone.color)
                        .shadow(color: milestone.color.opacity(0.5), radius: 10)
                }

                // Title
                Text(milestone.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                // Description
                Text(milestone.description)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                // Achievement badge
                if let badge = milestone.badge {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(badge)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(20)
                }

                // Continue button
                Button {
                    onDismiss()
                } label: {
                    Text("Continue Reading")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 200)
                        .padding()
                        .background(milestone.color)
                        .cornerRadius(25)
                }
                .padding(.top, 16)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            particleSystem.burst()
        }
    }
}

// MARK: - Reading Milestone

struct ReadingMilestone: Identifiable {
    let id = UUID()
    let type: MilestoneType
    let title: String
    let description: String
    let icon: String
    let color: Color
    let badge: String?

    enum MilestoneType {
        case chapterComplete
        case halfwayPoint
        case bookComplete
        case readingStreak
        case wordsRead
        case timeSpent
    }

    static func chapterComplete(_ chapter: Int, total: Int) -> ReadingMilestone {
        ReadingMilestone(
            type: .chapterComplete,
            title: "Chapter Complete!",
            description: "You've finished chapter \(chapter) of \(total)",
            icon: "checkmark.circle.fill",
            color: .green,
            badge: chapter == 1 ? "First Chapter!" : nil
        )
    }

    static func halfwayPoint(bookTitle: String) -> ReadingMilestone {
        ReadingMilestone(
            type: .halfwayPoint,
            title: "Halfway There!",
            description: "You're 50% through \(bookTitle)",
            icon: "flag.checkered",
            color: .orange,
            badge: "Halfway Hero"
        )
    }

    static func bookComplete(bookTitle: String) -> ReadingMilestone {
        ReadingMilestone(
            type: .bookComplete,
            title: "Book Complete!",
            description: "Congratulations! You've finished \(bookTitle)",
            icon: "trophy.fill",
            color: .yellow,
            badge: "Book Conqueror"
        )
    }

    static func readingStreak(_ days: Int) -> ReadingMilestone {
        ReadingMilestone(
            type: .readingStreak,
            title: "\(days) Day Streak!",
            description: "You've read for \(days) days in a row!",
            icon: "flame.fill",
            color: .red,
            badge: days >= 7 ? "Week Warrior" : nil
        )
    }
}

// MARK: - Particle System

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var position: CGPoint
        var velocity: CGPoint
        var color: Color
        var size: CGFloat
        var opacity: Double
        var rotation: Double
    }

    func burst() {
        let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue]
        let center = CGPoint(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)

        for _ in 0..<50 {
            let angle = Double.random(in: 0...2 * .pi)
            let speed = Double.random(in: 100...400)
            let particle = Particle(
                position: center,
                velocity: CGPoint(x: cos(angle) * speed, y: sin(angle) * speed),
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...12),
                opacity: 1.0,
                rotation: Double.random(in: 0...360)
            )
            particles.append(particle)
        }

        // Animate particles
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }

            DispatchQueue.main.async {
                var hasActiveParticles = false

                for i in self.particles.indices {
                    self.particles[i].position.x += self.particles[i].velocity.x * 0.016
                    self.particles[i].position.y += self.particles[i].velocity.y * 0.016
                    self.particles[i].velocity.y += 300 * 0.016 // gravity
                    self.particles[i].opacity -= 0.02
                    self.particles[i].rotation += 5

                    if self.particles[i].opacity > 0 {
                        hasActiveParticles = true
                    }
                }

                if !hasActiveParticles {
                    timer.invalidate()
                    self.particles.removeAll()
                }
            }
        }
    }
}

struct ParticleView: View {
    @ObservedObject var system: ParticleSystem

    var body: some View {
        Canvas { context, size in
            for particle in system.particles {
                guard particle.opacity > 0 else { continue }

                var contextCopy = context
                contextCopy.opacity = particle.opacity
                contextCopy.translateBy(x: particle.position.x, y: particle.position.y)
                contextCopy.rotate(by: .degrees(particle.rotation))

                let rect = CGRect(
                    x: -particle.size / 2,
                    y: -particle.size / 2,
                    width: particle.size,
                    height: particle.size
                )

                contextCopy.fill(
                    Path(roundedRect: rect, cornerRadius: particle.size / 4),
                    with: .color(particle.color)
                )
            }
        }
    }
}

// MARK: - Reading Streak Badge

struct ReadingStreakBadge: View {
    let currentStreak: Int
    let longestStreak: Int

    @State private var flameAnimation = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .scaleEffect(flameAnimation ? 1.1 : 1.0)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentStreak) day streak")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if currentStreak > 0 && currentStreak == longestStreak {
                    Text("Personal best!")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            if currentStreak > 0 {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    flameAnimation = true
                }
            }
        }
    }
}

// MARK: - Daily Reading Goal Progress

struct DailyReadingGoalView: View {
    let minutesRead: Int
    let goalMinutes: Int
    let isComplete: Bool

    @State private var animatedProgress: Double = 0

    private var progress: Double {
        min(1.0, Double(minutesRead) / Double(goalMinutes))
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        isComplete ? Color.green : Color.blue,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundColor(.green)
                } else {
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.bold)
                }
            }
            .frame(width: 50, height: 50)

            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(isComplete ? "Goal Complete!" : "Daily Goal")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isComplete ? .green : .primary)

                Text("\(minutesRead) / \(goalMinutes) minutes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isComplete ? Color.green.opacity(0.1) : Color(.systemGray6))
        )
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
    }
}
