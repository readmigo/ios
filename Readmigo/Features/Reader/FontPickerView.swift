import SwiftUI
import UniformTypeIdentifiers

// MARK: - Enhanced Font Picker View

struct EnhancedFontPickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingImportSheet = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var isImporting = false
    @State private var selectedCategory: FontCategory?

    private let fontManager = FontManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Category filter
                Section {
                    CategoryFilterView(selectedCategory: $selectedCategory)
                }

                // System fonts section
                if shouldShowCategory(.sansSerif) || shouldShowCategory(.serif) {
                    Section("font.systemFonts".localized) {
                        FontGridView(
                            fonts: filteredFonts(from: fontManager.systemFonts),
                            selectedFont: themeManager.readerFont,
                            onSelect: selectFont
                        )
                    }
                }

                // Chinese fonts section
                if shouldShowCategory(.chinese) {
                    Section("font.chineseFonts".localized) {
                        FontGridView(
                            fonts: fontManager.systemFonts.filter { $0.category == .chinese },
                            selectedFont: themeManager.readerFont,
                            onSelect: selectFont
                        )
                    }
                }

                // Bundled fonts section
                if !fontManager.bundledFonts.isEmpty {
                    Section {
                        FontGridView(
                            fonts: filteredFonts(from: fontManager.bundledFonts),
                            selectedFont: themeManager.readerFont,
                            onSelect: selectFont
                        )
                    } header: {
                        HStack {
                            Text("font.bundledFonts".localized)
                            Spacer()
                            Text("font.openSource".localized)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Imported fonts section
                Section {
                    if fontManager.importedFonts.isEmpty {
                        EmptyImportedFontsView(onImport: { showingImportSheet = true })
                    } else {
                        FontGridView(
                            fonts: filteredFonts(from: fontManager.importedFonts),
                            selectedFont: themeManager.readerFont,
                            onSelect: selectFont,
                            showDelete: true,
                            onDelete: deleteFont
                        )
                    }
                } header: {
                    HStack {
                        Text("font.importFonts".localized)
                        Spacer()
                        Button {
                            showingImportSheet = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                // Typography settings section
                Section("font.typographySettings".localized) {
                    TypographySettingsView()
                }

                // Preview section
                Section("font.preview".localized) {
                    FontPreviewCard(
                        font: themeManager.readerFont,
                        theme: themeManager.readerTheme,
                        fontSize: themeManager.fontSize
                    )
                }
            }
            .navigationTitle("font.settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.font, UTType(filenameExtension: "ttf")!, UTType(filenameExtension: "otf")!],
                allowsMultipleSelection: false
            ) { result in
                handleFontImport(result)
            }
            .alert("font.importFailed".localized, isPresented: $showingImportError) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(importError ?? "font.unknownError".localized)
            }
            .overlay {
                if isImporting {
                    ImportingOverlay()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func shouldShowCategory(_ category: FontCategory) -> Bool {
        guard let selected = selectedCategory else { return true }
        return selected == category
    }

    private func filteredFonts(from fonts: [ReaderFontFamily]) -> [ReaderFontFamily] {
        guard let category = selectedCategory else { return fonts }
        return fonts.filter { $0.category == category }
    }

    private func selectFont(_ font: ReaderFontFamily) {
        // Map ReaderFontFamily to ReaderFont enum
        if let readerFont = ReaderFont(rawValue: font.name) {
            withAnimation(.easeInOut(duration: 0.2)) {
                themeManager.readerFont = readerFont
            }
        }
    }

    private func deleteFont(_ font: ReaderFontFamily) {
        do {
            try themeManager.deleteImportedFont(font)
        } catch {
            importError = error.localizedDescription
            showingImportError = true
        }
    }

    private func handleFontImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isImporting = true
            Task {
                do {
                    _ = try await themeManager.importFont(from: url)
                    isImporting = false
                } catch {
                    isImporting = false
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true
        }
    }
}

// MARK: - Category Filter View

private struct CategoryFilterView: View {
    @Binding var selectedCategory: FontCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryChip(
                    title: "font.category.all".localized,
                    icon: "textformat",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation { selectedCategory = nil }
                }

                ForEach(FontCategory.allCases, id: \.self) { category in
                    CategoryChip(
                        title: category.displayName,
                        icon: category.icon,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Font Grid View

private struct FontGridView: View {
    let fonts: [ReaderFontFamily]
    let selectedFont: ReaderFont
    let onSelect: (ReaderFontFamily) -> Void
    var showDelete: Bool = false
    var onDelete: ((ReaderFontFamily) -> Void)?

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(fonts) { font in
                FontCard(
                    font: font,
                    isSelected: selectedFont.rawValue == font.name,
                    showDelete: showDelete && font.source == .imported,
                    onSelect: { onSelect(font) },
                    onDelete: { onDelete?(font) }
                )
            }
        }
        .padding(.vertical, 8)
    }
}

private struct FontCard: View {
    let font: ReaderFontFamily
    let isSelected: Bool
    var showDelete: Bool = false
    let onSelect: () -> Void
    var onDelete: (() -> Void)?

    @State private var showingDeleteConfirmation = false

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Text(font.sampleText.prefix(6))
                    .font(font.swiftUIFont(size: 16))
                    .lineLimit(1)
                    .frame(height: 24)

                Text(font.displayName)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .lineLimit(1)

                if font.source == .imported {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if showDelete {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("font.deleteFont".localized, systemImage: "trash")
                }
            }
        }
        .confirmationDialog("font.deleteConfirmation".localized, isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("common.delete".localized, role: .destructive) {
                onDelete?()
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
    }
}

// MARK: - Typography Settings View

private struct TypographySettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 16) {
            // Font weight
            HStack {
                Text("font.weight".localized)
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $themeManager.fontWeight) {
                    ForEach(ReaderFontWeight.allCases, id: \.self) { weight in
                        Text(weight.displayName).tag(weight)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            // Letter spacing
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("font.letterSpacing".localized)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", themeManager.letterSpacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $themeManager.letterSpacing, in: -2...5, step: 0.5)
            }

            Divider()

            // Word spacing
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("font.wordSpacing".localized)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.1f", themeManager.wordSpacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $themeManager.wordSpacing, in: 0...10, step: 1)
            }

            Divider()

            // Paragraph spacing
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("font.paragraphSpacing".localized)
                        .font(.subheadline)
                    Spacer()
                    Text(String(format: "%.0f", themeManager.paragraphSpacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Slider(value: $themeManager.paragraphSpacing, in: 0...30, step: 2)
            }

            Divider()

            // Text alignment
            HStack {
                Text("font.textAlignment".localized)
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $themeManager.textAlignment) {
                    ForEach(ReaderTextAlignment.allCases, id: \.self) { alignment in
                        Text(alignment.displayName).tag(alignment)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }

            Divider()

            // Hyphenation toggle
            Toggle("font.autoHyphenation".localized, isOn: $themeManager.hyphenation)
                .font(.subheadline)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Empty Imported Fonts View

private struct EmptyImportedFontsView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down")
                .font(.largeTitle)
                .foregroundColor(.secondary)

            Text("font.noImportedFonts".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("font.supportedFormats".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: onImport) {
                Label("font.importFonts".localized, systemImage: "plus")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Font Preview Card

private struct FontPreviewCard: View {
    let font: ReaderFont
    let theme: ReaderTheme
    let fontSize: FontSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pride and Prejudice")
                .font(.custom(font.rawValue, size: fontSize.textSize * 1.2).weight(.semibold))
                .foregroundColor(theme.textColor)

            Text("It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife.")
                .font(.custom(font.rawValue, size: fontSize.textSize))
                .foregroundColor(theme.textColor)
                .lineSpacing(fontSize.textSize * (fontSize.lineHeight - 1))

            HStack {
                Label(font.displayName, systemImage: "textformat")
                Spacer()
                Label("\(Int(fontSize.textSize))pt", systemImage: "textformat.size")
            }
            .font(.caption)
            .foregroundColor(theme.secondaryTextColor)
        }
        .padding()
        .background(theme.backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Importing Overlay

private struct ImportingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("font.importing".localized)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - Font Recommendation View

struct FontRecommendationView: View {
    let book: Book
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private var recommendations: [FontRecommendation] {
        themeManager.recommendFonts(for: book)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("font.recommendationDescription".localized(with: book.localizedTitle))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ForEach(recommendations.prefix(5)) { recommendation in
                    RecommendationRow(
                        recommendation: recommendation,
                        isSelected: themeManager.readerFont.rawValue == recommendation.font.name
                    ) {
                        if let font = ReaderFont(rawValue: recommendation.font.name) {
                            themeManager.readerFont = font
                        }
                    }
                }
            }
            .navigationTitle("font.recommendation".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct RecommendationRow: View {
    let recommendation: FontRecommendation
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(recommendation.font.displayName)
                            .font(.headline)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }

                    Text(recommendation.font.sampleText)
                        .font(recommendation.font.swiftUIFont(size: 14))
                        .foregroundColor(.secondary)

                    ForEach(recommendation.reasons, id: \.self) { reason in
                        Label(reason, systemImage: "sparkle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }

                Spacer()

                // Score indicator
                ScoreIndicator(score: recommendation.score)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ScoreIndicator: View {
    let score: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))

            Text("\(Int(score))")
                .font(.caption2.bold())
                .foregroundColor(scoreColor)
        }
    }

    private var scoreColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        default: return .gray
        }
    }
}
