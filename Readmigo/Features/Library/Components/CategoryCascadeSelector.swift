import SwiftUI

// MARK: - Models

/// A category in the cascade selection
struct CascadeCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let nameEn: String
    let slug: String
    let iconUrl: String?
    let bookCount: Int
    let hasChildren: Bool
}

/// A level in the cascade hierarchy
struct CascadeLevel: Codable {
    let level: Int
    let categories: [CascadeCategory]
    let selectedId: String?
}

/// Response from the cascade endpoint
struct CascadeResponse: Codable {
    let levels: [CascadeLevel]
    let selectedCategory: CascadeCategory?
}

// MARK: - View Model

@MainActor
class CategoryCascadeViewModel: ObservableObject {
    @Published var levels: [CascadeLevel] = []
    @Published var selectedCategory: CascadeCategory?
    @Published var selectedPath: [String] = []
    @Published var isLoading = false
    @Published var error: Error?

    func loadCascade() async {
        await loadCascade(path: selectedPath)
    }

    func loadCascade(path: [String]) async {
        isLoading = true
        error = nil

        do {
            let pathString = path.joined(separator: ",")
            let endpoint = path.isEmpty
                ? APIEndpoints.categoriesCascade
                : APIEndpoints.categoriesCascadeWithPath(pathString)

            let response: CascadeResponse = try await APIClient.shared.request(
                endpoint: endpoint,
                method: .get
            )

            self.levels = response.levels
            self.selectedCategory = response.selectedCategory
            self.selectedPath = path
        } catch {
            self.error = error
        }

        isLoading = false
    }

    func selectCategory(_ category: CascadeCategory, atLevel level: Int) async {
        // Build new path up to this level
        var newPath = Array(selectedPath.prefix(level))
        newPath.append(category.id)

        await loadCascade(path: newPath)
    }

    func clearSelection(fromLevel level: Int) async {
        let newPath = Array(selectedPath.prefix(level))
        await loadCascade(path: newPath)
    }
}

// MARK: - Views

/// A horizontal scrollable category cascade selector
struct CategoryCascadeSelector: View {
    @StateObject private var viewModel = CategoryCascadeViewModel()
    let onCategorySelected: ((CascadeCategory?) -> Void)?

    init(onCategorySelected: ((CascadeCategory?) -> Void)? = nil) {
        self.onCategorySelected = onCategorySelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoading && viewModel.levels.isEmpty {
                loadingView
            } else if let error = viewModel.error, viewModel.levels.isEmpty {
                errorView(error)
            } else {
                cascadeLevelsView
            }
        }
        .task {
            await viewModel.loadCascade()
        }
        .onChange(of: viewModel.selectedCategory) { newCategory in
            onCategorySelected?(newCategory)
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Text("Loading categories...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text("Failed to load categories")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Retry") {
                Task {
                    await viewModel.loadCascade()
                }
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var cascadeLevelsView: some View {
        ForEach(viewModel.levels, id: \.level) { level in
            CascadeLevelRow(
                level: level,
                onSelect: { category in
                    Task {
                        await viewModel.selectCategory(category, atLevel: level.level)
                    }
                },
                onClear: {
                    Task {
                        await viewModel.clearSelection(fromLevel: level.level)
                    }
                }
            )
        }
    }
}

/// A row showing one level of the cascade
struct CascadeLevelRow: View {
    let level: CascadeLevel
    let onSelect: (CascadeCategory) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Level header
            HStack {
                Text(levelTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                if level.selectedId != nil {
                    Button(action: onClear) {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)

            // Categories scroll view
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(level.categories) { category in
                        CascadeCategoryChip(
                            category: category,
                            isSelected: category.id == level.selectedId,
                            onTap: { onSelect(category) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var levelTitle: String {
        switch level.level {
        case 0: return "Category"
        case 1: return "Subcategory"
        case 2: return "Topic"
        default: return "Level \(level.level + 1)"
        }
    }
}

/// A single category chip for cascade selector
struct CascadeCategoryChip: View {
    let category: CascadeCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(category.nameEn)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                if category.hasChildren {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if category.bookCount > 0 {
                    Text("(\(category.bookCount))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#if DEBUG
struct CategoryCascadeSelector_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            CategoryCascadeSelector { category in
                print("Selected: \(category?.nameEn ?? "none")")
            }
        }
        .padding(.vertical)
    }
}
#endif
