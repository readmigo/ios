import SwiftUI

/// Popup shown when user taps on a highlight in text
struct HighlightDetailPopup: View {
    let highlight: Bookmark
    let onDismiss: () -> Void
    let onEdit: (Bookmark) -> Void
    let onDelete: (Bookmark) -> Void
    let onChangeColor: (Bookmark, HighlightColor) -> Void
    let onCopy: (String) -> Void

    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var editedNote: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Selected text preview
            ScrollView {
                Text(highlight.selectedText ?? "")
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((highlight.highlightColor ?? .yellow).backgroundColor)
                    )
                    .padding(.horizontal, 16)
            }
            .frame(maxHeight: 120)

            Divider()
                .padding(.vertical, 12)

            // Color picker row
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    ForEach(HighlightColor.allCases, id: \.self) { color in
                        Button {
                            onChangeColor(highlight, color)
                        } label: {
                            Circle()
                                .fill(color.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                                )
                                .overlay(
                                    highlight.highlightColor == color ?
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    : nil
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            Divider()
                .padding(.vertical, 12)

            // Note section
            if let note = highlight.note, !note.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Note")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            editedNote = note
                            isEditing = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)

                    Text(note)
                        .font(.system(size: 15))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                        .padding(.horizontal, 16)
                }

                Divider()
                    .padding(.vertical, 12)
            }

            // Action buttons
            HStack(spacing: 16) {
                // Copy button
                Button {
                    if let text = highlight.selectedText {
                        onCopy(text)
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 20))
                        Text("Copy")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                }

                // Add/Edit note button
                Button {
                    editedNote = highlight.note ?? ""
                    isEditing = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: highlight.note?.isEmpty == false ? "pencil.line" : "note.text.badge.plus")
                            .font(.system(size: 20))
                        Text(highlight.note?.isEmpty == false ? "Edit Note" : "Add Note")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                }

                // Delete button
                Button {
                    showDeleteConfirmation = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                        Text("Delete")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)
        .confirmationDialog(
            "Delete Highlight",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete(highlight)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the highlight and any associated notes.")
        }
        .sheet(isPresented: $isEditing) {
            NoteEditorSheet(
                note: $editedNote,
                selectedText: highlight.selectedText ?? "",
                highlightColor: highlight.highlightColor,
                onSave: { newNote in
                    // Create updated highlight with new note
                    var updatedHighlight = highlight
                    updatedHighlight.note = newNote.isEmpty ? nil : newNote
                    onEdit(updatedHighlight)
                    isEditing = false
                },
                onCancel: {
                    isEditing = false
                }
            )
        }
    }
}

// MARK: - Note Editor Sheet

struct NoteEditorSheet: View {
    @Binding var note: String
    let selectedText: String
    let highlightColor: HighlightColor?
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Selected text reference
                Text(selectedText)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill((highlightColor ?? .yellow).backgroundColor)
                    )
                    .padding(.horizontal, 16)

                // Note editor
                TextEditor(text: $note)
                    .font(.system(size: 16))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(UIColor.secondarySystemBackground))
                    )
                    .padding(.horizontal, 16)
                    .focused($isFocused)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle(note.isEmpty ? "Add Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(note)
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
