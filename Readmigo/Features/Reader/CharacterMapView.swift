import SwiftUI

struct CharacterMapView: View {
    let bookId: String
    let bookTitle: String

    @StateObject private var manager = CharacterMapManager.shared
    @State private var selectedCharacter: Character?
    @State private var viewMode: CharacterViewMode = .graph
    @State private var sortMethod: CharacterSortMethod = .importance
    @State private var filter = CharacterFilter()
    @State private var showFilter = false
    @State private var graphScale: CGFloat = 1.0
    @State private var graphOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                switch viewMode {
                case .graph:
                    graphView
                case .list:
                    listView
                case .grid:
                    gridView
                }

                // Loading overlay
                if manager.isLoading || manager.isAnalyzing {
                    loadingOverlay
                }
            }
            .navigationTitle("reader.characters.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // View mode
                        Section("reader.characters.view".localized) {
                            ForEach(CharacterViewMode.allCases, id: \.self) { mode in
                                Button {
                                    viewMode = mode
                                } label: {
                                    Label(mode.displayName, systemImage: mode.icon)
                                    if viewMode == mode {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }

                        // Sort (for list/grid)
                        if viewMode != .graph {
                            Section("reader.characters.sortBy".localized) {
                                ForEach(CharacterSortMethod.allCases, id: \.self) { method in
                                    Button {
                                        sortMethod = method
                                    } label: {
                                        Label(method.displayName, systemImage: method.icon)
                                        if sortMethod == method {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }

                        // Filter
                        Section {
                            Button {
                                showFilter = true
                            } label: {
                                Label("common.filter".localized, systemImage: "line.3.horizontal.decrease.circle")
                            }
                        }

                        // Refresh
                        Section {
                            Button {
                                Task {
                                    await manager.analyzeCharacters(bookId: bookId)
                                }
                            } label: {
                                Label("reader.characters.reanalyze".localized, systemImage: "brain.head.profile")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedCharacter) { character in
                CharacterDetailSheet(character: character, bookId: bookId)
            }
            .sheet(isPresented: $showFilter) {
                CharacterFilterSheet(filter: $filter)
            }
            .task {
                await manager.fetchCharacters(bookId: bookId)
            }
        }
    }

    // MARK: - Graph View

    private var graphView: some View {
        GeometryReader { geometry in
            let (nodes, edges) = manager.buildGraph(for: bookId)

            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // Graph content
                ForceDirectedGraph(
                    nodes: nodes,
                    edges: edges,
                    selectedCharacter: $selectedCharacter,
                    scale: $graphScale,
                    offset: $graphOffset,
                    size: geometry.size
                )
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        graphScale = max(0.5, min(3.0, value))
                    }
            )
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            let sortedCharacters = manager.getSortedCharacters(for: bookId, by: sortMethod)
                .filter { filter.matches($0) }

            ForEach(sortedCharacters) { character in
                CharacterListRow(character: character)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCharacter = character
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            let sortedCharacters = manager.getSortedCharacters(for: bookId, by: sortMethod)
                .filter { filter.matches($0) }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(sortedCharacters) { character in
                    CharacterGridCard(character: character)
                        .onTapGesture {
                            selectedCharacter = character
                        }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                if manager.isAnalyzing {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .symbolEffect(.pulse)

                    Text("reader.characters.analyzing".localized)
                        .font(.headline)

                    ProgressView(value: manager.analysisProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text("reader.characters.identifyingRelationships".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                    Text("common.loading".localized)
                        .font(.subheadline)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - View Mode

enum CharacterViewMode: String, CaseIterable {
    case graph
    case list
    case grid

    var displayName: String {
        switch self {
        case .graph: return "Graph"
        case .list: return "List"
        case .grid: return "Grid"
        }
    }

    var icon: String {
        switch self {
        case .graph: return "point.3.connected.trianglepath.dotted"
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        }
    }
}

// MARK: - Force Directed Graph

struct ForceDirectedGraph: View {
    let nodes: [CharacterNode]
    let edges: [CharacterEdge]
    @Binding var selectedCharacter: Character?
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let size: CGSize

    @State private var animatedNodes: [CharacterNode] = []
    @State private var isDragging: String? = nil

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Draw edges
            for edge in edges {
                guard let sourceNode = animatedNodes.first(where: { $0.id == edge.sourceId }),
                      let targetNode = animatedNodes.first(where: { $0.id == edge.targetId }) else {
                    continue
                }

                let start = transformPoint(sourceNode.position, center: center)
                let end = transformPoint(targetNode.position, center: center)

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(edge.color.opacity(0.6)),
                    lineWidth: edge.lineWidth * scale
                )
            }
        }
        .overlay {
            // Draw nodes
            ForEach(animatedNodes) { node in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let position = transformPoint(node.position, center: center)

                CharacterNodeView(
                    character: node.character,
                    size: node.size * scale,
                    isSelected: selectedCharacter?.id == node.id
                )
                .position(position)
                .onTapGesture {
                    selectedCharacter = node.character
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = node.id
                            if let index = animatedNodes.firstIndex(where: { $0.id == node.id }) {
                                animatedNodes[index].position = CGPoint(
                                    x: (value.location.x - center.x - offset.width) / scale,
                                    y: (value.location.y - center.y - offset.height) / scale
                                )
                                animatedNodes[index].isFixed = true
                            }
                        }
                        .onEnded { _ in
                            isDragging = nil
                            if let index = animatedNodes.firstIndex(where: { $0.id == node.id }) {
                                animatedNodes[index].isFixed = false
                            }
                        }
                )
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if isDragging == nil {
                        offset = CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        )
                    }
                }
        )
        .onAppear {
            animatedNodes = nodes
            runForceSimulation()
        }
    }

    private func transformPoint(_ point: CGPoint, center: CGPoint) -> CGPoint {
        CGPoint(
            x: center.x + point.x * scale + offset.width,
            y: center.y + point.y * scale + offset.height
        )
    }

    private func runForceSimulation() {
        // Simple force-directed layout
        Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { timer in
            var shouldContinue = false

            for i in animatedNodes.indices {
                guard !animatedNodes[i].isFixed else { continue }

                var force = CGPoint.zero

                // Repulsion from other nodes
                for j in animatedNodes.indices where i != j {
                    let dx = animatedNodes[i].position.x - animatedNodes[j].position.x
                    let dy = animatedNodes[i].position.y - animatedNodes[j].position.y
                    let distance = max(sqrt(dx * dx + dy * dy), 1)
                    let repulsion = 5000 / (distance * distance)
                    force.x += dx / distance * repulsion
                    force.y += dy / distance * repulsion
                }

                // Attraction to connected nodes
                for edge in edges {
                    var targetId: String?
                    if edge.sourceId == animatedNodes[i].id {
                        targetId = edge.targetId
                    } else if edge.targetId == animatedNodes[i].id {
                        targetId = edge.sourceId
                    }

                    if let targetId = targetId,
                       let targetNode = animatedNodes.first(where: { $0.id == targetId }) {
                        let dx = targetNode.position.x - animatedNodes[i].position.x
                        let dy = targetNode.position.y - animatedNodes[i].position.y
                        let distance = sqrt(dx * dx + dy * dy)
                        let attraction = distance * 0.01
                        force.x += dx / distance * attraction
                        force.y += dy / distance * attraction
                    }
                }

                // Center gravity
                force.x -= animatedNodes[i].position.x * 0.01
                force.y -= animatedNodes[i].position.y * 0.01

                // Apply force with damping
                animatedNodes[i].velocity.x = (animatedNodes[i].velocity.x + force.x) * 0.8
                animatedNodes[i].velocity.y = (animatedNodes[i].velocity.y + force.y) * 0.8

                animatedNodes[i].position.x += animatedNodes[i].velocity.x
                animatedNodes[i].position.y += animatedNodes[i].velocity.y

                if abs(animatedNodes[i].velocity.x) > 0.1 || abs(animatedNodes[i].velocity.y) > 0.1 {
                    shouldContinue = true
                }
            }

            if !shouldContinue {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Character Node View

struct CharacterNodeView: View {
    let character: Character
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Glow effect for selected
            if isSelected {
                Circle()
                    .fill(character.role.color.opacity(0.3))
                    .frame(width: size + 20, height: size + 20)
            }

            // Main circle
            Circle()
                .fill(character.role.color.opacity(0.2))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(character.role.color, lineWidth: isSelected ? 3 : 2)
                )

            // Avatar or initials
            if let imageUrl = character.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    initialsView
                }
                .frame(width: size - 8, height: size - 8)
                .clipShape(Circle())
            } else {
                initialsView
            }
        }
        .overlay(alignment: .bottom) {
            // Name label
            Text(character.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(.regularMaterial)
                .cornerRadius(4)
                .offset(y: size / 2 + 10)
        }
    }

    private var initialsView: some View {
        Text(character.name.prefix(2).uppercased())
            .font(.system(size: size * 0.35))
            .fontWeight(.bold)
            .foregroundColor(character.role.color)
    }
}

// MARK: - Character List Row

struct CharacterListRow: View {
    let character: Character

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(character.role.color.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(character.name.prefix(2).uppercased())
                        .font(.headline)
                        .foregroundColor(character.role.color)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(character.name)
                        .font(.headline)

                    if let chinese = character.nameChinese {
                        Text(chinese)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Text(character.shortDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Label(character.role.displayName, systemImage: character.role.icon)
                        .font(.caption2)
                        .foregroundColor(character.role.color)

                    Text("reader.characters.relationshipsCount".localized(with: character.relationships.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Character Grid Card

struct CharacterGridCard: View {
    let character: Character

    var body: some View {
        VStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(character.role.color.opacity(0.2))
                .frame(width: 70, height: 70)
                .overlay(
                    Text(character.name.prefix(2).uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(character.role.color)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: character.role.icon)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(4)
                        .background(character.role.color)
                        .clipShape(Circle())
                        .offset(x: 5, y: -5)
                }

            // Name
            VStack(spacing: 2) {
                Text(character.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                if let chinese = character.nameChinese {
                    Text(chinese)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Role
            Text(character.role.displayName)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(character.role.color)
                .cornerRadius(4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

// MARK: - Character Detail Sheet

struct CharacterDetailSheet: View {
    let character: Character
    let bookId: String
    @StateObject private var manager = CharacterMapManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    characterHeader

                    // Description
                    if let fullDescription = character.fullDescription {
                        sectionCard(title: "reader.characters.about".localized) {
                            Text(fullDescription)
                                .font(.body)
                        }
                    }

                    // Personality
                    if !character.personality.isEmpty {
                        sectionCard(title: "reader.characters.personality".localized) {
                            FlowLayout(spacing: 8) {
                                ForEach(character.personality) { trait in
                                    Text(trait.trait)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }

                    // Relationships
                    if !character.relationships.isEmpty {
                        sectionCard(title: "reader.characters.relationships".localized) {
                            VStack(spacing: 12) {
                                ForEach(character.relationships) { relationship in
                                    relationshipRow(relationship)
                                }
                            }
                        }
                    }

                    // First Appearance
                    sectionCard(title: "reader.characters.firstAppearance".localized) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reader.characters.chapterNumber".localized(with: character.firstAppearanceChapter + 1))
                                .font(.subheadline)
                                .fontWeight(.medium)

                            if let quote = character.firstAppearanceText {
                                Text("\"\(quote)\"")
                                    .font(.body)
                                    .italic()
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Motivations
                    if !character.motivations.isEmpty {
                        sectionCard(title: "reader.characters.motivations".localized) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(character.motivations, id: \.self) { motivation in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "arrow.right.circle.fill")
                                            .foregroundColor(.accentColor)
                                            .font(.caption)
                                        Text(motivation)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(character.name)
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

    private var characterHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            Circle()
                .fill(character.role.color.opacity(0.2))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(character.name.prefix(2).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(character.role.color)
                )

            // Name and Chinese
            VStack(spacing: 4) {
                Text(character.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let chinese = character.nameChinese {
                    Text(chinese)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }

            // Role badge
            HStack(spacing: 8) {
                Label(character.role.displayName, systemImage: character.role.icon)
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(character.role.color)
                    .cornerRadius(16)

                Text("reader.characters.mentionsCount".localized(with: character.mentionCount))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Short description
            Text(character.shortDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private func relationshipRow(_ relationship: CharacterRelationship) -> some View {
        HStack(spacing: 12) {
            Image(systemName: relationship.type.icon)
                .foregroundColor(relationship.type.lineColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(relationship.targetCharacterName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(relationship.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sentiment indicator
            Circle()
                .fill(relationship.sentiment.color)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Character Filter Sheet

struct CharacterFilterSheet: View {
    @Binding var filter: CharacterFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Roles
                Section("reader.characters.roles".localized) {
                    ForEach(CharacterRole.allCases, id: \.self) { role in
                        Toggle(isOn: Binding(
                            get: { filter.roles.contains(role) },
                            set: { isOn in
                                if isOn {
                                    filter.roles.insert(role)
                                } else {
                                    filter.roles.remove(role)
                                }
                            }
                        )) {
                            Label(role.displayName, systemImage: role.icon)
                                .foregroundColor(role.color)
                        }
                    }
                }

                // Importance
                Section("reader.characters.minimumImportance".localized) {
                    Slider(value: $filter.minimumImportance, in: 0...1)
                    Text("\(Int(filter.minimumImportance * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Reset
                Section {
                    Button("common.resetFilters".localized) {
                        filter = CharacterFilter()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("reader.characters.filterTitle".localized)
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
