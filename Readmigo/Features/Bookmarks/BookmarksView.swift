import SwiftUI

struct BookmarksView: View {
    let bookId: String
    let onNavigate: (BookmarkPosition) -> Void

    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var selectedFilter: BookmarkType? = nil
    @State private var searchText = ""
    @State private var showDeleteAlert = false
    @State private var bookmarkToDelete: Bookmark?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Chips
                filterChips

                Divider()

                // Content
                if filteredItems.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(filteredItems) { bookmark in
                            BookmarksPageRow(bookmark: bookmark)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onNavigate(bookmark.position)
                                    dismiss()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        bookmarkToDelete = bookmark
                                        showDeleteAlert = true
                                    } label: {
                                        Label("common.delete".localized, systemImage: "trash")
                                    }

                                    if bookmark.type == .highlight || bookmark.type == .annotation {
                                        Button {
                                            // Edit action
                                        } label: {
                                            Label("common.edit".localized, systemImage: "pencil")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("bookmarks.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "bookmarks.searchPrompt".localized)
            .alert("bookmarks.deleteTitle".localized, isPresented: $showDeleteAlert) {
                Button("common.cancel".localized, role: .cancel) {}
                Button("common.delete".localized, role: .destructive) {
                    if let bookmark = bookmarkToDelete {
                        Task {
                            await bookmarkManager.deleteBookmark(bookmark)
                        }
                    }
                }
            } message: {
                Text("bookmarks.deleteConfirm".localized)
            }
            .task {
                await bookmarkManager.fetchBookmarks(bookId: bookId)
            }
        }
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "common.all".localized,
                    count: allItems.count,
                    isSelected: selectedFilter == nil,
                    color: .blue
                ) {
                    selectedFilter = nil
                }

                ForEach(BookmarkType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        count: itemCount(for: type),
                        isSelected: selectedFilter == type,
                        color: type.color
                    ) {
                        selectedFilter = type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedFilter?.icon ?? "bookmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text(emptyTitle)
                .font(.headline)

            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyTitle: String {
        if !searchText.isEmpty {
            return "search.noResults".localized
        }
        switch selectedFilter {
        case .bookmark: return "bookmarks.empty.bookmarks".localized
        case .highlight: return "bookmarks.empty.highlights".localized
        case .annotation: return "bookmarks.empty.notes".localized
        case nil: return "bookmarks.empty.all".localized
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "search.tryDifferent".localized
        }
        switch selectedFilter {
        case .bookmark: return "bookmarks.hint.bookmark".localized
        case .highlight: return "bookmarks.hint.highlight".localized
        case .annotation: return "bookmarks.hint.annotation".localized
        case nil: return "bookmarks.hint.all".localized
        }
    }

    // MARK: - Computed Properties

    private var allItems: [Bookmark] {
        bookmarkManager.getAllItems(for: bookId)
    }

    private var filteredItems: [Bookmark] {
        var items = allItems

        // Filter by type
        if let filter = selectedFilter {
            items = items.filter { $0.type == filter }
        }

        // Filter by search
        if !searchText.isEmpty {
            items = items.filter { bookmark in
                (bookmark.selectedText?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (bookmark.note?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (bookmark.title?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return items
    }

    private func itemCount(for type: BookmarkType) -> Int {
        switch type {
        case .bookmark: return bookmarkManager.getBookmarks(for: bookId).count
        case .highlight: return bookmarkManager.getHighlights(for: bookId).count
        case .annotation: return bookmarkManager.getAnnotations(for: bookId).count
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected ? Color.white.opacity(0.3) : color.opacity(0.2)
                        )
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Bookmarks Page Row

struct BookmarksPageRow: View {
    let bookmark: Bookmark

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: bookmark.type.icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Title or selected text preview
                if let text = bookmark.selectedText, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(bookmark.highlightColor?.backgroundColor ?? Color.yellow.opacity(0.3))
                        .cornerRadius(4)
                } else if let title = bookmark.title {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                // Note
                if let note = bookmark.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Position info
                HStack(spacing: 8) {
                    Text(bookmark.position.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(timeAgo)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Navigation chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var iconColor: Color {
        switch bookmark.type {
        case .bookmark: return .blue
        case .highlight: return bookmark.highlightColor?.color ?? .yellow
        case .annotation: return .orange
        }
    }

    private var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: bookmark.createdAt, relativeTo: Date())
    }
}

// MARK: - Highlight Color Picker

struct HighlightColorPicker: View {
    @Binding var selectedColor: HighlightColor

    var body: some View {
        HStack(spacing: 16) {
            ForEach(HighlightColor.allCases, id: \.self) { color in
                Circle()
                    .fill(color.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                    )
                    .overlay(
                        selectedColor == color ?
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        : nil
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }
        }
    }
}

// MARK: - Create Highlight Sheet

struct CreateHighlightSheet: View {
    let bookId: String
    let chapterId: String
    let position: BookmarkPosition
    let selectedText: String
    let onSave: (Bookmark?) -> Void

    @StateObject private var bookmarkManager = BookmarkManager.shared
    @State private var note = ""
    @State private var highlightColor: HighlightColor = .yellow
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Selected text preview
                Section("highlight.selectedText".localized) {
                    Text(selectedText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(highlightColor.backgroundColor)
                        .cornerRadius(4)
                }

                // Color picker
                Section("highlight.color".localized) {
                    HighlightColorPicker(selectedColor: $highlightColor)
                        .padding(.vertical, 8)
                }

                // Note
                Section("highlight.addNote".localized) {
                    TextField("highlight.notePlaceholder".localized, text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("highlight.addTitle".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        saveHighlight()
                    }
                    .fontWeight(.semibold)
                    .disabled(isSaving)
                }
            }
        }
    }

    private func saveHighlight() {
        isSaving = true
        Task {
            let bookmark = await bookmarkManager.createHighlight(
                bookId: bookId,
                chapterId: chapterId,
                position: position,
                selectedText: selectedText,
                color: highlightColor,
                note: note.isEmpty ? nil : note
            )
            onSave(bookmark)
            dismiss()
        }
    }
}
