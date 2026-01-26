import SwiftUI

struct PostcardEditorView: View {
    @StateObject private var manager = PostcardsManager.shared
    @StateObject private var quotesManager = QuotesManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var draft = PostcardDraft()
    @State private var currentStep: EditorStep = .template
    @State private var showQuotePicker = false
    @State private var showColorPicker = false
    @State private var isSaving = false

    enum EditorStep: Int, CaseIterable {
        case template
        case content
        case style
        case preview

        var title: String {
            switch self {
            case .template: return "Template"
            case .content: return "Content"
            case .style: return "Style"
            case .preview: return "Preview"
            }
        }

        var icon: String {
            switch self {
            case .template: return "rectangle.stack"
            case .content: return "text.quote"
            case .style: return "paintbrush"
            case .preview: return "eye"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress Steps
                StepIndicator(currentStep: currentStep)
                    .padding()

                // Content
                TabView(selection: $currentStep) {
                    TemplateStepView(
                        draft: $draft,
                        templates: manager.templates
                    )
                    .tag(EditorStep.template)

                    ContentStepView(
                        draft: $draft,
                        showQuotePicker: $showQuotePicker
                    )
                    .tag(EditorStep.content)

                    StyleStepView(
                        draft: $draft,
                        showColorPicker: $showColorPicker
                    )
                    .tag(EditorStep.style)

                    PreviewStepView(draft: draft)
                        .tag(EditorStep.preview)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentStep != .template {
                        Button(action: previousStep) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                        }
                    }

                    if currentStep == .preview {
                        Button(action: savePostcard) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark")
                                    Text("Create")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCreate ? Color.accentColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canCreate || isSaving)
                    } else {
                        Button(action: nextStep) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canProceed ? Color.accentColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(!canProceed)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Create Postcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showQuotePicker) {
                QuotePickerView(selectedQuote: $draft.quote) { quote in
                    draft.quoteId = quote.id
                    draft.quote = PostcardQuote(
                        id: quote.id,
                        text: quote.text,
                        author: quote.author,
                        source: quote.bookTitle
                    )
                }
            }
            .task {
                await manager.fetchTemplates()
            }
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case .template: return draft.template != nil
        case .content: return !draft.displayText.isEmpty
        case .style: return true
        case .preview: return true
        }
    }

    private var canCreate: Bool {
        draft.template != nil && !draft.displayText.isEmpty
    }

    private func nextStep() {
        if let nextIndex = EditorStep.allCases.firstIndex(of: currentStep).map({ $0 + 1 }),
           nextIndex < EditorStep.allCases.count {
            withAnimation {
                currentStep = EditorStep.allCases[nextIndex]
            }
        }
    }

    private func previousStep() {
        if let prevIndex = EditorStep.allCases.firstIndex(of: currentStep).map({ $0 - 1 }),
           prevIndex >= 0 {
            withAnimation {
                currentStep = EditorStep.allCases[prevIndex]
            }
        }
    }

    private func savePostcard() {
        isSaving = true

        Task {
            if let postcard = await manager.createPostcard(from: draft) {
                await MainActor.run {
                    dismiss()
                }
            }
            isSaving = false
        }
    }
}

// MARK: - Step Indicator

struct StepIndicator: View {
    let currentStep: PostcardEditorView.EditorStep

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PostcardEditorView.EditorStep.allCases, id: \.self) { step in
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(step.rawValue <= currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 32, height: 32)

                        Image(systemName: step.icon)
                            .font(.caption)
                            .foregroundColor(step.rawValue <= currentStep.rawValue ? .white : .gray)
                    }

                    Text(step.title)
                        .font(.caption2)
                        .foregroundColor(step == currentStep ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)

                if step != PostcardEditorView.EditorStep.allCases.last {
                    Rectangle()
                        .fill(step.rawValue < currentStep.rawValue ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(height: 2)
                        .frame(maxWidth: 40)
                }
            }
        }
    }
}

// MARK: - Template Step

struct TemplateStepView: View {
    @Binding var draft: PostcardDraft
    let templates: [PostcardTemplate]

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Choose a template")
                    .font(.headline)
                    .padding(.horizontal)

                if templates.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(templates) { template in
                            TemplateCard(
                                template: template,
                                isSelected: draft.templateId == template.id
                            ) {
                                draft.templateId = template.id
                                draft.template = template
                                draft.backgroundColor = template.backgroundColor
                                draft.textColor = template.fontColor
                                draft.fontFamily = template.fontFamily
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
}

struct TemplateCard: View {
    let template: PostcardTemplate
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(template.bgColor)

                    if let previewUrl = template.previewUrl, let url = URL(string: previewUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.clear
                        }
                        .clipped()
                    }

                    VStack {
                        Text("Sample Quote")
                            .font(.caption)
                            .foregroundColor(template.txtColor)
                    }
                    .padding()

                    if template.isPremium {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "crown.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .padding(6)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        .padding(8)
                    }
                }
                .aspectRatio(3/4, contentMode: .fit)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

                Text(template.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Content Step

struct ContentStepView: View {
    @Binding var draft: PostcardDraft
    @Binding var showQuotePicker: Bool

    @State private var useCustomText = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Add your content")
                    .font(.headline)
                    .padding(.horizontal)

                // Source Toggle
                Picker("Content Source", selection: $useCustomText) {
                    Text("Select Quote").tag(false)
                    Text("Custom Text").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                if useCustomText {
                    // Custom Text Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your text")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextEditor(text: Binding(
                            get: { draft.customText ?? "" },
                            set: { draft.customText = $0 }
                        ))
                        .frame(minHeight: 150)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)

                        Text("\(draft.customText?.count ?? 0)/280 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                } else {
                    // Quote Selection
                    VStack(spacing: 16) {
                        if let quote = draft.quote {
                            SelectedQuoteCard(quote: quote) {
                                draft.quote = nil
                                draft.quoteId = nil
                            }
                        } else {
                            Button(action: { showQuotePicker = true }) {
                                HStack {
                                    Image(systemName: "text.quote")
                                    Text("Select a Quote")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
        .onChange(of: useCustomText) { _, isCustom in
            if isCustom {
                draft.quote = nil
                draft.quoteId = nil
            } else {
                draft.customText = nil
            }
        }
    }
}

struct SelectedQuoteCard: View {
    let quote: PostcardQuote
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Selected Quote")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }

            Text("\"\(quote.text)\"")
                .font(.subheadline)
                .italic()

            if let author = quote.author {
                Text("— \(author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Style Step

struct StyleStepView: View {
    @Binding var draft: PostcardDraft
    @Binding var showColorPicker: Bool

    let presetColors = [
        "#FFFFFF", "#F8F8F8", "#1A1A1A", "#2C3E50",
        "#E74C3C", "#3498DB", "#2ECC71", "#F39C12",
        "#9B59B6", "#1ABC9C", "#E91E63", "#607D8B"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Customize style")
                    .font(.headline)
                    .padding(.horizontal)

                // Background Color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Background Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            ColorSwatch(
                                color: color,
                                isSelected: draft.backgroundColor == color
                            ) {
                                draft.backgroundColor = color
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Text Color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Text Color")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(presetColors, id: \.self) { color in
                            ColorSwatch(
                                color: color,
                                isSelected: draft.textColor == color
                            ) {
                                draft.textColor = color
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Font Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Font Style")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(PostcardFont.allCases, id: \.self) { font in
                        FontOption(
                            font: font,
                            isSelected: draft.fontFamily == font.rawValue
                        ) {
                            draft.fontFamily = font.rawValue
                        }
                    }
                }
                .padding(.horizontal)

                // Visibility Toggle
                Toggle(isOn: $draft.isPublic) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Make Public")
                            .font(.subheadline)
                        Text("Allow others to see your postcard")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
}

struct ColorSwatch: View {
    let color: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1)
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(contrastColor)
                        .opacity(isSelected ? 1 : 0)
                )
        }
    }

    private var contrastColor: Color {
        Color(hex: color).luminance > 0.5 ? .black : .white
    }
}

struct FontOption: View {
    let font: PostcardFont
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text("Aa")
                    .font(font.font(size: 20))

                Text(font.displayName)
                    .font(.subheadline)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Step

struct PreviewStepView: View {
    let draft: PostcardDraft

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Preview")
                    .font(.headline)

                // Postcard Preview
                PostcardPreviewCard(draft: draft)
                    .padding(.horizontal)

                // Summary
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text("Template")
                        Spacer()
                        Text(draft.template?.name ?? "None")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Visibility")
                        Spacer()
                        Text(draft.isPublic ? "Public" : "Private")
                            .foregroundColor(.secondary)
                    }

                    if let author = draft.quote?.author {
                        HStack {
                            Text("Quote by")
                            Spacer()
                            Text(author)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .font(.subheadline)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
}

struct PostcardPreviewCard: View {
    let draft: PostcardDraft

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(draft.bgColor)

            VStack(spacing: 16) {
                Spacer()

                Text(draft.displayText)
                    .font(fontFromFamily(draft.fontFamily ?? "System", size: 18))
                    .foregroundColor(draft.txtColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                if let author = draft.quote?.author {
                    Text("— \(author)")
                        .font(.caption)
                        .foregroundColor(draft.txtColor.opacity(0.8))
                }

                Spacer()
            }
            .padding()
        }
        .aspectRatio(3/4, contentMode: .fit)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    private func fontFromFamily(_ family: String, size: CGFloat) -> Font {
        switch family {
        case "Georgia": return .custom("Georgia", size: size)
        case "Menlo": return .custom("Menlo", size: size)
        case "SF Pro Rounded": return .system(size: size, design: .rounded)
        default: return .system(size: size)
        }
    }
}

// MARK: - Quote Picker

struct QuotePickerView: View {
    @StateObject private var quotesManager = QuotesManager.shared
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedQuote: PostcardQuote?
    let onSelect: (Quote) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if quotesManager.quotes.isEmpty && quotesManager.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        ForEach(quotesManager.quotes) { quote in
                            Button {
                                onSelect(quote)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("\"\(quote.text)\"")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(3)

                                    HStack {
                                        Text(quote.author)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        if let book = quote.bookTitle {
                                            Text(book)
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Select Quote")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                if quotesManager.quotes.isEmpty {
                    await quotesManager.fetchQuotes()
                }
            }
        }
    }
}

// MARK: - Color Luminance Extension

extension Color {
    var luminance: Double {
        // Approximate luminance calculation
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return 0.299 * Double(red) + 0.587 * Double(green) + 0.114 * Double(blue)
    }
}
