import SwiftUI

/// Text selection action menu with highlight colors and note option
struct TextSelectionMenu: View {
    let selectedText: String
    let sentence: String
    let bookId: String
    let chapterId: String
    let chapterIndex: Int
    let scrollPercentage: Double

    let onHighlight: (HighlightColor) -> Void
    let onAddNote: () -> Void
    let onAIExplain: () -> Void
    let onAISimplify: () -> Void
    let onAITranslate: () -> Void
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var showNoteInput = false
    @State private var noteText = ""
    @StateObject private var bookmarkManager = BookmarkManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            if showNoteInput {
                noteInputSection
            } else {
                menuContent
            }
        }
        .background(Color(.systemBackground))
        .customCornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.15), radius: 10, y: -5)
    }

    // MARK: - Menu Content

    private var menuContent: some View {
        VStack(spacing: 16) {
            // Selected text preview
            Text(selectedText.prefix(100) + (selectedText.count > 100 ? "..." : ""))
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Highlight color row
            highlightColorRow

            Divider()
                .padding(.horizontal)

            // AI actions row
            aiActionsRow

            // Utility actions row
            utilityActionsRow
        }
        .padding(.bottom, 20)
    }

    // MARK: - Highlight Colors

    private var highlightColorRow: some View {
        HStack(spacing: 16) {
            Text("selection.highlight".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            ForEach(HighlightColor.allCases, id: \.self) { color in
                Button {
                    createHighlight(color: color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }

            // Add note button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNoteInput = true
                }
            } label: {
                Image(systemName: "note.text.badge.plus")
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - AI Actions

    private var aiActionsRow: some View {
        HStack(spacing: 12) {
            SelectionMenuActionButton(icon: "book.fill", title: "selection.explain".localized, color: .blue) {
                onAIExplain()
            }

            SelectionMenuActionButton(icon: "text.alignleft", title: "selection.simplify".localized, color: .green) {
                onAISimplify()
            }

            SelectionMenuActionButton(icon: "globe", title: "selection.translate".localized, color: .purple) {
                onAITranslate()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Utility Actions

    private var utilityActionsRow: some View {
        HStack(spacing: 12) {
            SelectionMenuActionButton(icon: "doc.on.doc", title: "selection.copy".localized, color: .gray) {
                UIPasteboard.general.string = selectedText
                onCopy()
            }

            SelectionMenuActionButton(icon: "xmark", title: "common.cancel".localized, color: .secondary) {
                onDismiss()
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Note Input Section

    private var noteInputSection: some View {
        VStack(spacing: 12) {
            // Selected text preview
            Text(selectedText.prefix(50) + (selectedText.count > 50 ? "..." : ""))
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            // Note input field
            VStack(alignment: .leading, spacing: 8) {
                Text("selection.addThought".localized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                TextEditor(text: $noteText)
                    .frame(height: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            // Color picker for note highlight
            HStack(spacing: 12) {
                ForEach(HighlightColor.allCases, id: \.self) { color in
                    Button {
                        createAnnotation(color: color, note: noteText)
                    } label: {
                        Circle()
                            .fill(color.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }

                Spacer()

                Button("common.cancel".localized) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNoteInput = false
                        noteText = ""
                    }
                }
                .foregroundColor(.secondary)

                Button("common.save".localized) {
                    createAnnotation(color: .yellow, note: noteText)
                }
                .disabled(noteText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Actions

    private func createHighlight(color: HighlightColor) {
        Task {
            let position = BookmarkPosition(
                chapterIndex: chapterIndex,
                paragraphIndex: nil,
                characterOffset: nil,
                scrollPercentage: scrollPercentage,
                cfiPath: nil
            )

            _ = await bookmarkManager.createHighlight(
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                selectedText: selectedText,
                color: color,
                note: nil
            )

            onHighlight(color)
        }
    }

    private func createAnnotation(color: HighlightColor, note: String) {
        Task {
            let position = BookmarkPosition(
                chapterIndex: chapterIndex,
                paragraphIndex: nil,
                characterOffset: nil,
                scrollPercentage: scrollPercentage,
                cfiPath: nil
            )

            _ = await bookmarkManager.createHighlight(
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                selectedText: selectedText,
                color: color,
                note: note.isEmpty ? nil : note
            )

            onHighlight(color)
        }
    }
}

// MARK: - Selection Menu Action Button

private struct SelectionMenuActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: - Custom Corner Radius

private extension View {
    func customCornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(SelectionMenuRoundedCorner(radius: radius, corners: corners))
    }
}

private struct SelectionMenuRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
