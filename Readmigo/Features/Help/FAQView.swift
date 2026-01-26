import SwiftUI

struct FAQView: View {
    @StateObject private var service = FAQService.shared
    @State private var searchText = ""
    @State private var selectedFAQ: FAQ?
    @State private var expandedCategories: Set<String> = []

    var body: some View {
        List {
            // Search section
            Section {
                searchField
            }

            // Search results or categories
            if !searchText.isEmpty {
                searchResultsSection
            } else {
                // Featured FAQs
                if !service.featuredFAQs.isEmpty {
                    featuredSection
                }

                // Categories
                ForEach(service.categories) { category in
                    categorySection(category)
                }
            }
        }
        .navigationTitle("faq.title".localized)
        .refreshable {
            await loadData()
        }
        .overlay {
            if service.isLoading && service.categories.isEmpty {
                ProgressView()
            }
        }
        .sheet(item: $selectedFAQ) { faq in
            FAQDetailSheet(faq: faq)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("faq.searchPlaceholder".localized, text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    service.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: searchText) { _, newValue in
            Task {
                await service.searchFAQs(query: newValue)
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        Section {
            if service.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if service.searchResults.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("faq.noResults".localized)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ForEach(service.searchResults) { faq in
                    FAQRow(faq: faq) {
                        selectedFAQ = faq
                    }
                }
            }
        } header: {
            Text("faq.searchResults".localized(with: service.searchResults.count))
        }
    }

    // MARK: - Featured Section

    private var featuredSection: some View {
        Section {
            ForEach(service.featuredFAQs) { faq in
                FAQRow(faq: faq, isPinned: true) {
                    selectedFAQ = faq
                }
            }
        } header: {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundStyle(.orange)
                Text("faq.featured".localized)
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(_ category: FAQCategory) -> some View {
        Section {
            // Category header (expandable)
            Button {
                withAnimation {
                    if expandedCategories.contains(category.id) {
                        expandedCategories.remove(category.id)
                    } else {
                        expandedCategories.insert(category.id)
                    }
                }
            } label: {
                HStack {
                    if let icon = category.icon {
                        Image(systemName: icon)
                            .foregroundStyle(.accentColor)
                            .frame(width: 24)
                    }

                    Text(category.localizedName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Spacer()

                    Text("\(category.faqCount)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())

                    Image(systemName: expandedCategories.contains(category.id) ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // FAQs (when expanded)
            if expandedCategories.contains(category.id) {
                ForEach(category.faqs) { faq in
                    FAQRow(faq: faq) {
                        selectedFAQ = faq
                    }
                }
            }
        }
    }

    // MARK: - Methods

    private func loadData() async {
        async let faqs: () = service.loadAllFAQs()
        async let featured: () = service.loadFeaturedFAQs()
        _ = await (faqs, featured)
    }
}

// MARK: - FAQ Row

struct FAQRow: View {
    let faq: FAQ
    var isPinned: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if isPinned || faq.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }

                        Text(faq.localizedQuestion)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }

                    HStack(spacing: 12) {
                        if faq.viewCount > 0 {
                            Label("\(faq.viewCount)", systemImage: "eye")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if faq.helpfulYes + faq.helpfulNo > 0 {
                            Label("\(Int(faq.helpfulPercentage))%", systemImage: "hand.thumbsup")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - FAQ Detail Sheet

struct FAQDetailSheet: View {
    let faq: FAQ
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackSubmitted = false
    @State private var feedbackValue: Bool?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Question
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundStyle(.accentColor)
                            Text("faq.question".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(faq.localizedQuestion)
                            .font(.headline)
                    }

                    Divider()

                    // Answer
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.orange)
                            Text("faq.answer".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(faq.localizedAnswer)
                            .font(.body)
                    }

                    Divider()

                    // Feedback
                    VStack(alignment: .leading, spacing: 12) {
                        Text("faq.feedbackPrompt".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if feedbackSubmitted {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("faq.thanksFeedback".localized)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            HStack(spacing: 16) {
                                Button {
                                    submitFeedback(helpful: true)
                                } label: {
                                    Label("faq.helpful".localized, systemImage: "hand.thumbsup")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(feedbackValue == true ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
                                        .foregroundStyle(feedbackValue == true ? .green : .primary)
                                        .clipShape(Capsule())
                                }

                                Button {
                                    submitFeedback(helpful: false)
                                } label: {
                                    Label("faq.notHelpful".localized, systemImage: "hand.thumbsdown")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(feedbackValue == false ? Color.red.opacity(0.15) : Color.secondary.opacity(0.1))
                                        .foregroundStyle(feedbackValue == false ? .red : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Stats
                    HStack(spacing: 20) {
                        Label("faq.viewCount".localized(with: faq.viewCount), systemImage: "eye")
                        if faq.helpfulYes + faq.helpfulNo > 0 {
                            Label("faq.helpfulPercent".localized(with: Int(faq.helpfulPercentage)), systemImage: "hand.thumbsup")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("faq.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.close".localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func submitFeedback(helpful: Bool) {
        feedbackValue = helpful
        Task {
            let success = await FAQService.shared.submitFeedback(faqId: faq.id, helpful: helpful)
            if success {
                feedbackSubmitted = true
            }
        }
    }
}
