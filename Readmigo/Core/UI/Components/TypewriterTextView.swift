import SwiftUI

/// A text view that displays content with a typewriter animation effect.
/// Used to create an engaging "AI is generating" experience even when content comes from cache.
struct TypewriterTextView: View {
    let fullText: String
    let fromCache: Bool
    var onComplete: (() -> Void)?

    @State private var displayedText = ""
    @State private var isComplete = false
    @State private var currentIndex = 0

    /// Character delay based on whether content is from cache
    /// Cache: faster animation (8ms), Real-time: slower animation (15ms)
    private var charDelay: UInt64 {
        fromCache ? 8_000_000 : 15_000_000  // nanoseconds
    }

    /// Initial delay before starting animation (simulates "processing")
    private var initialDelay: UInt64 {
        fromCache ? UInt64.random(in: 200_000_000...400_000_000) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayedText)
                .font(.body)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !isComplete {
                TypingIndicator()
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .task {
            await animateText()
        }
        .onChange(of: fullText) { _, newValue in
            // Reset and reanimate if text changes
            displayedText = ""
            isComplete = false
            currentIndex = 0
            Task {
                await animateText()
            }
        }
    }

    private func animateText() async {
        // Initial delay for cached content to simulate processing
        if initialDelay > 0 {
            try? await Task.sleep(nanoseconds: initialDelay)
        }

        // Animate character by character
        for char in fullText {
            guard !Task.isCancelled else { break }

            displayedText.append(char)
            currentIndex += 1

            // Variable speed: faster for spaces and punctuation
            let delay = char.isWhitespace || char.isPunctuation ? charDelay / 2 : charDelay
            try? await Task.sleep(nanoseconds: delay)
        }

        withAnimation(.easeOut(duration: 0.2)) {
            isComplete = true
        }

        onComplete?()
    }
}

// MARK: - Typing Indicator (Three bouncing dots)

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 6, height: 6)
                    .offset(y: animating ? -4 : 0)
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            animating = true
        }
    }
}

// MARK: - Shimmer Loading View (Alternative loading state)

struct ShimmerLoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.gray.opacity(0.2),
                                Color.gray.opacity(0.4),
                                Color.gray.opacity(0.2)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 16)
                    .frame(maxWidth: index == 3 ? 200 : .infinity)
                    .mask(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white, .clear],
                                    startPoint: .leading,
                                    endPoint: isAnimating ? .trailing : .leading
                                )
                            )
                    )
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - AI Response View with Typewriter Effect

struct AIResponseView: View {
    let content: String
    let fromCache: Bool
    let action: AIAction

    @State private var showCopyConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with cache indicator (only in debug)
            #if DEBUG
            if fromCache {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                    Text("From cache")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            #endif

            // Animated content
            TypewriterTextView(
                fullText: content,
                fromCache: fromCache
            )
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
