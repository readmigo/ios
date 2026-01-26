import SwiftUI

// MARK: - Chapter Transition Overlay

struct ChapterTransitionOverlay: View {
    let fromChapter: Int
    let toChapter: Int
    let chapterTitle: String
    let isVisible: Bool
    let onComplete: () -> Void

    @State private var progress: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.black.opacity(0.9), .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                // Animated chapter indicator
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 4)
                        .frame(width: 120, height: 120)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))

                    // Chapter number
                    VStack(spacing: 4) {
                        Text("Chapter")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))

                        Text("\(toChapter + 1)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                // Chapter title
                VStack(spacing: 8) {
                    Text(chapterTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .opacity(textOpacity)

                    if fromChapter < toChapter {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                            Text("Moving forward")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(textOpacity)
                    }
                }
            }
        }
        .opacity(isVisible ? 1 : 0)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                progress = 0
                textOpacity = 0
                withAnimation(.easeOut(duration: 0.8)) {
                    progress = 1
                }
                withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
                    textOpacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    onComplete()
                }
            }
        }
    }
}

// MARK: - Scroll Progress Indicator

struct ScrollProgressIndicator: View {
    let progress: Double
    let style: IndicatorStyle

    enum IndicatorStyle {
        case bar
        case dots
        case chapters
    }

    var body: some View {
        switch style {
        case .bar:
            barIndicator
        case .dots:
            dotsIndicator
        case .chapters:
            chaptersIndicator
        }
    }

    private var barIndicator: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 3)

                Capsule()
                    .fill(Color.white)
                    .frame(width: max(20, geometry.size.width * progress), height: 3)
            }
        }
        .frame(height: 3)
    }

    private var dotsIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                let dotProgress = Double(index) / 4.0
                Circle()
                    .fill(progress >= dotProgress ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var chaptersIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<10, id: \.self) { index in
                let chapterProgress = Double(index) / 9.0
                RoundedRectangle(cornerRadius: 2)
                    .fill(progress >= chapterProgress ? Color.white : Color.white.opacity(0.2))
                    .frame(width: progress >= chapterProgress ? 20 : 15, height: 4)
            }
        }
    }
}

// MARK: - Page Number Badge

struct PageNumberBadge: View {
    let currentPage: Int
    let totalPages: Int
    let style: BadgeStyle

    enum BadgeStyle {
        case minimal
        case detailed
        case percentage
    }

    var body: some View {
        Group {
            switch style {
            case .minimal:
                Text("\(currentPage)/\(totalPages)")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .detailed:
                HStack(spacing: 4) {
                    Text("Page")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(currentPage)")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("of")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(totalPages)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }

            case .percentage:
                let percentage = totalPages > 0 ? Int((Double(currentPage) / Double(totalPages)) * 100) : 0
                Text("\(percentage)%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
