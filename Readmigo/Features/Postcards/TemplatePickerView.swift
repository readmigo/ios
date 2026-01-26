import SwiftUI

struct TemplatePickerView: View {
    @StateObject private var manager = PostcardsManager.shared
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedTemplate: PostcardTemplate?
    @State private var selectedCategory: TemplateCategory?
    @State private var showPaywall = false

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        TemplateCategoryChip(
                            category: nil,
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                        }

                        ForEach(TemplateCategory.allCases, id: \.self) { category in
                            TemplateCategoryChip(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemBackground))

                Divider()

                // Templates Grid
                ScrollView {
                    if manager.isLoading && manager.templates.isEmpty {
                        ProgressView()
                            .padding()
                    } else if filteredTemplates.isEmpty {
                        EmptyTemplatesView()
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(filteredTemplates) { template in
                                TemplatePickerCard(
                                    template: template,
                                    isSelected: selectedTemplate?.id == template.id,
                                    isLocked: template.isPremium && !subscriptionManager.isSubscribed
                                ) {
                                    if template.isPremium && !subscriptionManager.isSubscribed {
                                        showPaywall = true
                                    } else {
                                        selectedTemplate = template
                                        dismiss()
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .task {
                await manager.fetchTemplates()
            }
        }
    }

    private var filteredTemplates: [PostcardTemplate] {
        if let category = selectedCategory {
            return manager.templates.filter { $0.category == category }
        }
        return manager.templates
    }
}

// MARK: - Template Category Chip

private struct TemplateCategoryChip: View {
    let category: TemplateCategory?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(.caption)
                }
                Text(category?.displayName ?? "All")
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

// MARK: - Template Picker Card

struct TemplatePickerCard: View {
    let template: PostcardTemplate
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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

                // Sample text
                Text("Aa")
                    .font(.title2)
                    .foregroundColor(template.txtColor)

                // Locked overlay
                if isLocked {
                    ZStack {
                        Color.black.opacity(0.4)

                        VStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.title3)
                                .foregroundColor(.yellow)
                            Text("Premium")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                }

                // Selected indicator
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .background(Circle().fill(.white))
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
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty Templates View

struct EmptyTemplatesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Templates")
                .font(.headline)

            Text("No templates found in this category.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Template Preview Sheet

struct TemplatePreviewSheet: View {
    let template: PostcardTemplate
    let onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Large Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
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

                    VStack(spacing: 12) {
                        Spacer()
                        Text("Sample Quote Text")
                            .font(.title3)
                            .foregroundColor(template.txtColor)
                            .multilineTextAlignment(.center)

                        Text("— Author Name")
                            .font(.subheadline)
                            .foregroundColor(template.txtColor.opacity(0.8))
                        Spacer()
                    }
                    .padding(32)
                }
                .aspectRatio(3/4, contentMode: .fit)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                .padding(.horizontal)

                // Template Info
                VStack(spacing: 8) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 16) {
                        if let category = template.category {
                            Label(category.displayName, systemImage: category.icon)
                        }
                        if template.isPremium {
                            Label("Premium", systemImage: "crown.fill")
                                .foregroundColor(.yellow)
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Select Button
                Button(action: {
                    onSelect()
                    dismiss()
                }) {
                    Text("Use This Template")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .padding(.vertical)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
