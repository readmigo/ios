import SwiftUI

// MARK: - Synced Reader View

/// A text view that highlights content synchronized with audiobook playback.
/// Supports both sentence-level and word-level highlighting.
struct SyncedReaderView: View {
    let text: String
    @ObservedObject var syncManager: HighlightSyncManager

    // Configuration
    var fontSize: CGFloat = 18
    var lineSpacing: CGFloat = 8
    var highlightColor: Color = .yellow.opacity(0.4)
    var wordHighlightColor: Color = .yellow.opacity(0.7)
    var textColor: Color = .primary
    var onTapText: ((Int) -> Void)?  // Callback with character offset

    @State private var scrollToSegmentId: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                HighlightedTextView(
                    text: text,
                    highlightRange: syncManager.highlightRange,
                    wordHighlightRange: syncManager.wordHighlightRange,
                    fontSize: fontSize,
                    lineSpacing: lineSpacing,
                    highlightColor: highlightColor,
                    wordHighlightColor: wordHighlightColor,
                    textColor: textColor,
                    onTap: { charOffset in
                        syncManager.seekToText(at: charOffset)
                        onTapText?(charOffset)
                    }
                )
                .padding()
            }
            .onChange(of: syncManager.currentSegment?.id) { _, segmentId in
                // Auto-scroll to current segment
                if let segmentId = segmentId {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(segmentId, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Highlighted Text View

/// UIViewRepresentable for efficient text highlighting
struct HighlightedTextView: UIViewRepresentable {
    let text: String
    let highlightRange: HighlightRange?
    let wordHighlightRange: HighlightRange?
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let highlightColor: Color
    let wordHighlightColor: Color
    let textColor: Color
    let onTap: ((Int) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        textView.addGestureRecognizer(tapGesture)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onTap = onTap

        // Build attributed string
        let attributedText = buildAttributedString()
        textView.attributedText = attributedText
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    private func buildAttributedString() -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor(textColor),
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: baseAttributes
        )

        // Apply sentence highlight
        if let range = highlightRange, range.length > 0 {
            let nsRange = NSRange(
                location: max(0, range.location),
                length: min(range.length, text.count - max(0, range.location))
            )

            if nsRange.location + nsRange.length <= text.count {
                attributedString.addAttribute(
                    .backgroundColor,
                    value: UIColor(highlightColor),
                    range: nsRange
                )
            }
        }

        // Apply word highlight (on top of sentence highlight)
        if let wordRange = wordHighlightRange, wordRange.length > 0 {
            let nsRange = NSRange(
                location: max(0, wordRange.location),
                length: min(wordRange.length, text.count - max(0, wordRange.location))
            )

            if nsRange.location + nsRange.length <= text.count {
                attributedString.addAttribute(
                    .backgroundColor,
                    value: UIColor(wordHighlightColor),
                    range: nsRange
                )
            }
        }

        return attributedString
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var onTap: ((Int) -> Void)?

        init(onTap: ((Int) -> Void)?) {
            self.onTap = onTap
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let textView = gesture.view as? UITextView else { return }

            let location = gesture.location(in: textView)
            let position = textView.closestPosition(to: location)

            if let position = position {
                let offset = textView.offset(from: textView.beginningOfDocument, to: position)
                onTap?(offset)
            }
        }
    }
}

// MARK: - Sync Status Badge

/// Shows the sync status and controls
struct SyncStatusBadge: View {
    @ObservedObject var syncManager: HighlightSyncManager

    var body: some View {
        HStack(spacing: 6) {
            if syncManager.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else if syncManager.hasTimestamps {
                Image(systemName: syncManager.isActive ? "waveform" : "waveform.slash")
                    .foregroundColor(syncManager.isActive ? .green : .gray)

                if syncManager.isActive {
                    Text("highlightSync.syncing".localized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "waveform.slash")
                    .foregroundColor(.gray)

                Text("highlightSync.unavailable".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
