import SwiftUI

struct ReaderSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var showingFontPicker = false
    @State private var showingAdvancedSettings = false
    @State private var showingPageTurnSettings = false

    var body: some View {
        NavigationStack {
            List {
                // Font Size Section
                Section("reader.settings.fontSize".localized) {
                    FontSizePicker(selectedSize: $themeManager.fontSize)
                }

                // Font Family Section - with navigation to enhanced picker
                Section {
                    FontFamilyPicker(selectedFont: $themeManager.readerFont)
                } header: {
                    HStack {
                        Text("reader.settings.font".localized)
                        Spacer()
                        Button {
                            showingFontPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("common.more".localized)
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }

                // Theme Section
                Section("reader.settings.theme".localized) {
                    ThemePicker(selectedTheme: $themeManager.readerTheme)
                }

                // Reading Mode Section
                Section {
                    // Basic reading modes
                    ReadingModePicker(selectedMode: $themeManager.readingMode)

                    // Advanced page turn settings entry
                    Button {
                        showingPageTurnSettings = true
                    } label: {
                        HStack {
                            Label("reader.settings.advancedPageTurn".localized, systemImage: "book.pages.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text(themeManager.pageTurnSettings.mode.displayName)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("reader.settings.pageTurnMode".localized)
                        Spacer()
                        if themeManager.readingMode.supportsAutoPage {
                            Toggle(isOn: $themeManager.autoPageEnabled) {
                                Label("common.auto".localized, systemImage: "timer")
                                    .font(.caption)
                            }
                            .toggleStyle(.button)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // Auto Page Interval (only when auto page is enabled)
                if themeManager.autoPageEnabled && themeManager.readingMode.supportsAutoPage {
                    Section("reader.settings.autoPageInterval".localized) {
                        Picker("reader.settings.interval".localized, selection: $themeManager.autoPageInterval) {
                            ForEach(AutoPageInterval.allCases, id: \.self) { interval in
                                Text(interval.displayName).tag(interval)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Tap zone hint for paged modes
                if themeManager.readingMode.isPaged {
                    Section {
                        TapZoneHintView()
                    } header: {
                        Text("reader.settings.tapZones".localized)
                    }
                }

                // Quick Typography Settings
                Section {
                    QuickTypographySettingsView()
                } header: {
                    HStack {
                        Text("reader.settings.typography".localized)
                        Spacer()
                        Button {
                            showingAdvancedSettings = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("reader.settings.advancedSettings".localized)
                                    .font(.caption)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }

                // Preview Section
                Section("reader.settings.preview".localized) {
                    PreviewCard(
                        theme: themeManager.readerTheme,
                        fontSize: themeManager.fontSize,
                        font: themeManager.readerFont
                    )
                }
            }
            .navigationTitle("reader.settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFontPicker) {
                EnhancedFontPickerView()
                    .environmentObject(themeManager)
            }
            .sheet(isPresented: $showingAdvancedSettings) {
                NavigationStack {
                    AdvancedReaderSettingsView()
                        .environmentObject(themeManager)
                }
            }
            .sheet(isPresented: $showingPageTurnSettings) {
                PageTurnSettingsView(settingsManager: PageTurnSettingsManager.shared)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Quick Typography Settings

private struct QuickTypographySettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            // Text alignment quick picker
            HStack {
                Text("reader.settings.alignment".localized)
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $themeManager.textAlignment) {
                    Image(systemName: "text.alignleft").tag(ReaderTextAlignment.left)
                    Image(systemName: "text.aligncenter").tag(ReaderTextAlignment.center)
                    Image(systemName: "text.alignright").tag(ReaderTextAlignment.right)
                    Image(systemName: "text.justify").tag(ReaderTextAlignment.justified)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            Divider()

            // Hyphenation toggle
            Toggle("reader.settings.autoHyphenation".localized, isOn: $themeManager.hyphenation)
                .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Font Size Picker

struct FontSizePicker: View {
    @Binding var selectedSize: FontSize

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Aa")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(FontSize.allCases.firstIndex(of: selectedSize) ?? 1) },
                        set: { selectedSize = FontSize.allCases[Int($0)] }
                    ),
                    in: 0...Double(FontSize.allCases.count - 1),
                    step: 1
                )

                Text("Aa")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }

            Text(selectedSize.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Font Family Picker

struct FontFamilyPicker: View {
    @Binding var selectedFont: ReaderFont

    var body: some View {
        VStack(spacing: 12) {
            // Grouped font categories
            VStack(alignment: .leading, spacing: 8) {
                Text("font.systemFonts".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    FontButton(font: .system, selectedFont: $selectedFont)
                    FontButton(font: .systemSerif, selectedFont: $selectedFont)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("font.westernFonts".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    FontButton(font: .georgia, selectedFont: $selectedFont)
                    FontButton(font: .palatino, selectedFont: $selectedFont)
                    FontButton(font: .times, selectedFont: $selectedFont)
                    FontButton(font: .baskerville, selectedFont: $selectedFont)
                    FontButton(font: .helvetica, selectedFont: $selectedFont)
                    FontButton(font: .avenir, selectedFont: $selectedFont)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("font.chineseFonts".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    FontButton(font: .pingfang, selectedFont: $selectedFont)
                    FontButton(font: .songti, selectedFont: $selectedFont)
                    FontButton(font: .kaiti, selectedFont: $selectedFont)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct FontButton: View {
    let font: ReaderFont
    @Binding var selectedFont: ReaderFont

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFont = font
            }
        } label: {
            VStack(spacing: 4) {
                Text(font.sampleText.prefix(6))
                    .font(.custom(font.rawValue, size: 14))
                    .lineLimit(1)
                    .frame(height: 20)

                Text(font.displayName)
                    .font(.caption2)
                    .foregroundColor(selectedFont == font ? .accentColor : .secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedFont == font ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Theme Picker

struct ThemePicker: View {
    @Binding var selectedTheme: ReaderTheme

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ReaderTheme.allCases, id: \.self) { theme in
                ThemeButton(
                    theme: theme,
                    isSelected: selectedTheme == theme
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTheme = theme
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct ThemeButton: View {
    let theme: ReaderTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.backgroundColor)
                    .frame(width: 60, height: 60)

                Text("Aa")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(theme.textColor)

                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 3)
                        .frame(width: 60, height: 60)
                }
            }
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            Text(theme.displayName)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Reading Mode Picker

struct ReadingModePicker: View {
    @Binding var selectedMode: ReadingMode

    var body: some View {
        HStack(spacing: 16) {
            ForEach(ReadingMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .frame(width: 70, height: 50)

                            Image(systemName: mode.icon)
                                .font(.title2)
                                .foregroundColor(selectedMode == mode ? .accentColor : .secondary)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedMode == mode ? Color.accentColor : Color.clear, lineWidth: 2)
                        )

                        Text(mode.displayName)
                            .font(.caption)
                            .foregroundColor(selectedMode == mode ? .accentColor : .secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview Card

struct PreviewCard: View {
    let theme: ReaderTheme
    let fontSize: FontSize
    let font: ReaderFont

    private var sampleText: String {
        font.isSerif ? "It is a truth universally acknowledged, that a single man in possession of a good fortune, must be in want of a wife." : font.sampleText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pride and Prejudice")
                .font(.custom(font.rawValue, size: fontSize.textSize * 1.2).weight(.semibold))
                .foregroundColor(theme.textColor)

            Text(sampleText)
                .font(.custom(font.rawValue, size: fontSize.textSize))
                .foregroundColor(theme.textColor)
                .lineSpacing(fontSize.textSize * (fontSize.lineHeight - 1))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Tap Zone Hint View

struct TapZoneHintView: View {
    var body: some View {
        HStack(spacing: 2) {
            // Left zone - previous page
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.2))
                VStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                    Text("reader.tapZone.prevPage".localized)
                        .font(.system(size: 8))
                }
                .foregroundColor(.blue)
            }
            .frame(width: 50, height: 60)

            // Center zone - menu
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                VStack(spacing: 2) {
                    Image(systemName: "line.3.horizontal")
                        .font(.caption2)
                    Text("reader.tapZone.menu".localized)
                        .font(.system(size: 8))
                }
                .foregroundColor(.secondary)
            }
            .frame(width: 100, height: 60)

            // Right zone - next page
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.2))
                VStack(spacing: 2) {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                    Text("reader.tapZone.nextPage".localized)
                        .font(.system(size: 8))
                }
                .foregroundColor(.blue)
            }
            .frame(width: 50, height: 60)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Advanced Settings

struct AdvancedReaderSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showPageNumbers") private var showPageNumbers = true

    var body: some View {
        List {
            // Typography Section
            Section("reader.settings.typographySettings".localized) {
                // Font weight
                HStack {
                    Label("font.weight".localized, systemImage: "bold")
                    Spacer()
                    Picker("", selection: $themeManager.fontWeight) {
                        ForEach(ReaderFontWeight.allCases, id: \.self) { weight in
                            Text(weight.displayName).tag(weight)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Letter spacing
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("reader.settings.letterSpacing".localized, systemImage: "arrow.left.and.right")
                        Spacer()
                        Text(String(format: "%.1f", themeManager.letterSpacing))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Slider(value: $themeManager.letterSpacing, in: -2...5, step: 0.5)
                }

                // Word spacing
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("reader.settings.wordSpacing".localized, systemImage: "space")
                        Spacer()
                        Text(String(format: "%.0f", themeManager.wordSpacing))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Slider(value: $themeManager.wordSpacing, in: 0...10, step: 1)
                }

                // Paragraph spacing
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("reader.settings.paragraphSpacing".localized, systemImage: "arrow.up.and.down")
                        Spacer()
                        Text(String(format: "%.0f", themeManager.paragraphSpacing))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    Slider(value: $themeManager.paragraphSpacing, in: 0...30, step: 2)
                }
            }

            Section("reader.settings.textLayout".localized) {
                // Text alignment
                HStack {
                    Label("reader.settings.textAlignment".localized, systemImage: "text.alignleft")
                    Spacer()
                    Picker("", selection: $themeManager.textAlignment) {
                        ForEach(ReaderTextAlignment.allCases, id: \.self) { alignment in
                            Text(alignment.displayName).tag(alignment)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Toggle(isOn: $themeManager.hyphenation) {
                    Label("reader.settings.hyphenation".localized, systemImage: "minus")
                }
            }

            Section("reader.settings.display".localized) {
                Toggle(isOn: $showPageNumbers) {
                    Label("reader.settings.showPageNumbers".localized, systemImage: "number")
                }

                HStack {
                    Label("reader.settings.screenBrightness".localized, systemImage: "sun.max")
                    Spacer()
                    Toggle("", isOn: $themeManager.autoBrightness)
                }

                if !themeManager.autoBrightness {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "sun.min")
                            Slider(value: $themeManager.brightness, in: 0...1)
                            Image(systemName: "sun.max")
                        }
                    }
                }
            }

            Section("reader.settings.darkMode".localized) {
                Picker(selection: $themeManager.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Label(mode.displayName, systemImage: mode.icon).tag(mode)
                    }
                } label: {
                    Label("settings.appearance".localized, systemImage: "circle.lefthalf.filled")
                }
            }

            // Reset to defaults
            Section {
                Button(role: .destructive) {
                    resetToDefaults()
                } label: {
                    Label("reader.settings.resetDefaults".localized, systemImage: "arrow.counterclockwise")
                }
            }
        }
        .navigationTitle("reader.settings.advanced".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("common.done".localized) {
                    dismiss()
                }
            }
        }
    }

    private func resetToDefaults() {
        themeManager.letterSpacing = 0
        themeManager.wordSpacing = 0
        themeManager.paragraphSpacing = 12
        themeManager.textAlignment = .justified
        themeManager.hyphenation = true
        themeManager.fontWeight = .regular
    }
}
