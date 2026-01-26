import SwiftUI
import UIKit

// MARK: - Focus Mode Types

enum FocusModeType: String, CaseIterable, Codable {
    case none
    case bionic         // Bold first part of words
    case highlight      // Highlight current paragraph
    case spotlight      // Dim everything except focus area
    case ruler          // Reading ruler line
    case typoglycemia   // Randomize middle letters (for dyslexia training)

    var displayName: String {
        switch self {
        case .none: return "Off"
        case .bionic: return "Bionic Reading"
        case .highlight: return "Paragraph Focus"
        case .spotlight: return "Spotlight"
        case .ruler: return "Reading Ruler"
        case .typoglycemia: return "Letter Flow"
        }
    }

    var description: String {
        switch self {
        case .none: return "Standard reading experience"
        case .bionic: return "Bold word beginnings for faster reading"
        case .highlight: return "Focus on one paragraph at a time"
        case .spotlight: return "Dim surrounding text"
        case .ruler: return "Guide line for easier tracking"
        case .typoglycemia: return "Improve reading flexibility"
        }
    }

    var icon: String {
        switch self {
        case .none: return "eye"
        case .bionic: return "textformat.abc"
        case .highlight: return "text.line.first.and.arrowtriangle.forward"
        case .spotlight: return "light.beacon.max"
        case .ruler: return "ruler"
        case .typoglycemia: return "character"
        }
    }
}

// MARK: - Bionic Reading Text View

struct BionicReadingText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let boldRatio: Double // How much of word to bold (0.3-0.5 recommended)

    var body: some View {
        bionicAttributedText
    }

    private var bionicAttributedText: Text {
        let words = text.split(separator: " ", omittingEmptySubsequences: false)
        var result = Text("")

        for (index, word) in words.enumerated() {
            let wordStr = String(word)

            if wordStr.isEmpty {
                result = result + Text(" ")
                continue
            }

            let bionicWord = createBionicWord(wordStr)
            result = result + bionicWord

            if index < words.count - 1 {
                result = result + Text(" ")
            }
        }

        return result
    }

    private func createBionicWord(_ word: String) -> Text {
        guard word.count > 1 else {
            return Text(word)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(textColor)
        }

        // Calculate bold portion
        let boldLength = max(1, Int(Double(word.count) * boldRatio))
        let boldPart = String(word.prefix(boldLength))
        let normalPart = String(word.dropFirst(boldLength))

        return Text(boldPart)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(textColor) +
        Text(normalPart)
            .font(.system(size: fontSize, weight: .regular))
            .foregroundColor(textColor.opacity(0.7))
    }
}

// MARK: - Spotlight Focus View

struct SpotlightFocusView<Content: View>: View {
    @Binding var focusPosition: CGPoint
    let spotlightRadius: CGFloat
    let dimOpacity: Double
    @ViewBuilder let content: () -> Content

    @State private var animatedPosition: CGPoint = .zero

    var body: some View {
        ZStack {
            content()

            // Spotlight mask
            Canvas { context, size in
                // Full dim overlay
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(dimOpacity))
                )

                // Clear spotlight area
                context.blendMode = .destinationOut
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: animatedPosition.x - spotlightRadius,
                        y: animatedPosition.y - spotlightRadius,
                        width: spotlightRadius * 2,
                        height: spotlightRadius * 2
                    )),
                    with: .color(.black)
                )

                // Soft edge gradient
                let gradient = Gradient(colors: [
                    .clear,
                    .black.opacity(dimOpacity * 0.5),
                    .black.opacity(dimOpacity)
                ])
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: animatedPosition.x - spotlightRadius * 1.2,
                        y: animatedPosition.y - spotlightRadius * 1.2,
                        width: spotlightRadius * 2.4,
                        height: spotlightRadius * 2.4
                    )),
                    with: .radialGradient(
                        gradient,
                        center: animatedPosition,
                        startRadius: spotlightRadius,
                        endRadius: spotlightRadius * 1.2
                    )
                )
            }
            .allowsHitTesting(false)
        }
        .onChange(of: focusPosition) { _, newValue in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                animatedPosition = newValue
            }
        }
        .onAppear {
            animatedPosition = focusPosition
        }
    }
}

// MARK: - Reading Ruler View

struct ReadingRulerView: View {
    @Binding var rulerPosition: CGFloat
    let rulerColor: Color
    let rulerHeight: CGFloat
    let showGuideLines: Bool

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top dim area
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: max(0, rulerPosition + dragOffset - rulerHeight / 2))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // Ruler line
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(rulerColor)
                        .frame(height: 2)

                    if showGuideLines {
                        // Side markers
                        Circle()
                            .fill(rulerColor)
                            .frame(width: 8, height: 8)
                    }
                }
                .offset(y: rulerPosition + dragOffset - geometry.size.height / 2)

                // Bottom dim area
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: max(0, geometry.size.height - (rulerPosition + dragOffset + rulerHeight / 2)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                // Clear reading area
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: rulerHeight)
                    .offset(y: rulerPosition + dragOffset - geometry.size.height / 2)
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        rulerPosition = min(
                            max(rulerHeight, rulerPosition + value.translation.height),
                            geometry.size.height - rulerHeight
                        )
                    }
            )
        }
    }
}

// MARK: - Paragraph Focus View

struct ParagraphFocusView: View {
    let paragraphs: [String]
    @Binding var focusedIndex: Int
    let fontSize: CGFloat
    let textColor: Color
    let highlightColor: Color

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, paragraph in
                        Text(paragraph)
                            .font(.system(size: fontSize))
                            .foregroundColor(
                                index == focusedIndex ? textColor : textColor.opacity(0.3)
                            )
                            .lineSpacing(8)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(index == focusedIndex ? highlightColor : Color.clear)
                            )
                            .id(index)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    focusedIndex = index
                                }
                            }
                    }
                }
                .padding()
            }
            .onChange(of: focusedIndex) { _, newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.height < -50 {
                            focusedIndex = min(focusedIndex + 1, paragraphs.count - 1)
                        } else if value.translation.height > 50 {
                            focusedIndex = max(focusedIndex - 1, 0)
                        }
                    }
            )
        }
    }
}

// MARK: - Haptic Feedback Manager

@MainActor
class HapticFeedbackManager: ObservableObject {
    static let shared = HapticFeedbackManager()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    var isEnabled: Bool = true

    private init() {
        prepareGenerators()
    }

    func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Reader-specific Haptics

    func pageForward() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func pageBackward() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    func chapterChange() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func bookmarkAdded() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func bookmarkRemoved() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    func highlightCreated() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    func textSelected() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    func ttsWordHighlight() {
        guard isEnabled else { return }
        // Very subtle haptic for TTS word highlighting
        impactLight.impactOccurred(intensity: 0.3)
    }

    func ttsSentenceComplete() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.5)
    }

    func milestoneReached() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }

    func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    func scrollEdgeReached() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.7)
    }

    func sliderChange() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    func buttonTap() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.5)
    }

    func longPress() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    // Custom intensity haptic
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat = 1.0) {
        guard isEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred(intensity: intensity)
    }

    // Rhythm haptic pattern
    func rhythmPattern(_ pattern: HapticPattern) {
        guard isEnabled else { return }

        Task {
            for (index, beat) in pattern.beats.enumerated() {
                impact(style: beat.style, intensity: beat.intensity)

                if index < pattern.beats.count - 1 {
                    try? await Task.sleep(nanoseconds: UInt64(pattern.intervalMs * 1_000_000))
                }
            }
        }
    }
}

// MARK: - Haptic Pattern

struct HapticPattern {
    let beats: [HapticBeat]
    let intervalMs: Int

    struct HapticBeat {
        let style: UIImpactFeedbackGenerator.FeedbackStyle
        let intensity: CGFloat
    }

    static let celebration = HapticPattern(
        beats: [
            HapticBeat(style: .medium, intensity: 1.0),
            HapticBeat(style: .light, intensity: 0.8),
            HapticBeat(style: .heavy, intensity: 1.0)
        ],
        intervalMs: 100
    )

    static let warning = HapticPattern(
        beats: [
            HapticBeat(style: .medium, intensity: 0.8),
            HapticBeat(style: .medium, intensity: 0.8)
        ],
        intervalMs: 150
    )

    static let complete = HapticPattern(
        beats: [
            HapticBeat(style: .light, intensity: 0.5),
            HapticBeat(style: .medium, intensity: 0.8),
            HapticBeat(style: .heavy, intensity: 1.0)
        ],
        intervalMs: 80
    )
}

// MARK: - Focus Mode Selector View

struct FocusModeSelector: View {
    @Binding var selectedMode: FocusModeType
    @Binding var bionicIntensity: Double
    @Binding var spotlightRadius: CGFloat
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(FocusModeType.allCases, id: \.self) { mode in
                        Button {
                            selectedMode = mode
                            HapticFeedbackManager.shared.selection()
                        } label: {
                            HStack {
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                    .foregroundColor(selectedMode == mode ? .accentColor : .secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .foregroundColor(.primary)
                                    Text(mode.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if selectedMode == mode {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Reading Focus Mode")
                }

                if selectedMode == .bionic {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bold Intensity")
                                .font(.subheadline)

                            Slider(value: $bionicIntensity, in: 0.2...0.6, step: 0.1)
                                .tint(.accentColor)

                            // Preview
                            BionicReadingText(
                                text: "The quick brown fox jumps over the lazy dog.",
                                fontSize: 16,
                                textColor: .primary,
                                boldRatio: bionicIntensity
                            )
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    } header: {
                        Text("Bionic Reading Settings")
                    }
                }

                if selectedMode == .spotlight {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Spotlight Size")
                                .font(.subheadline)

                            Slider(value: $spotlightRadius, in: 50...200)
                                .tint(.accentColor)

                            HStack {
                                Text("Small")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Large")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Spotlight Settings")
                    }
                }
            }
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Dyslexia-Friendly Text View

struct DyslexiaFriendlyText: View {
    let text: String
    let fontSize: CGFloat
    let textColor: Color
    let letterSpacing: CGFloat
    let lineHeight: CGFloat
    let useOpenDyslexic: Bool

    var body: some View {
        Text(text)
            .font(useOpenDyslexic ? Font.custom("OpenDyslexic", size: fontSize) : .system(size: fontSize))
            .foregroundColor(textColor)
            .tracking(letterSpacing)
            .lineSpacing(lineHeight)
    }
}
