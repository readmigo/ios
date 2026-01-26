import SwiftUI

struct StoryTimelineView: View {
    let bookId: String
    let bookTitle: String
    let currentChapter: Int
    let onNavigate: (Int, Double) -> Void // chapter, position

    @StateObject private var manager = TimelineManager.shared
    @State private var viewMode: TimelineViewMode = .timeline
    @State private var filter = TimelineFilter()
    @State private var showFilter = false
    @State private var selectedEvent: TimelineEvent?
    @State private var selectedArc: StoryArc?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                switch viewMode {
                case .timeline:
                    timelineView
                case .arc:
                    storyArcView
                case .chapter:
                    chapterView
                }

                if manager.isLoading || manager.isAnalyzing {
                    loadingOverlay
                }
            }
            .navigationTitle("reader.timeline.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Picker("View", selection: $viewMode) {
                        ForEach(TimelineViewMode.allCases, id: \.self) { mode in
                            Image(systemName: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showFilter = true
                        } label: {
                            Label("common.filter".localized, systemImage: "line.3.horizontal.decrease.circle")
                        }

                        Button {
                            Task {
                                await manager.analyzeTimeline(bookId: bookId)
                            }
                        } label: {
                            Label("reader.timeline.reanalyze".localized, systemImage: "brain.head.profile")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailSheet(event: event, onNavigate: { chapter, position in
                    onNavigate(chapter, position)
                    dismiss()
                })
            }
            .sheet(isPresented: $showFilter) {
                TimelineFilterSheet(filter: $filter, bookId: bookId)
            }
            .task {
                await manager.fetchTimeline(bookId: bookId)
            }
        }
    }

    // MARK: - Timeline View

    private var timelineView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    let filteredEvents = manager.getFilteredEvents(for: bookId, filter: filter)
                    let groupedEvents = Dictionary(grouping: filteredEvents, by: { $0.chapterIndex })
                    let sortedChapters = groupedEvents.keys.sorted()

                    ForEach(sortedChapters, id: \.self) { chapter in
                        if let events = groupedEvents[chapter] {
                            ChapterEventsSection(
                                chapter: chapter,
                                events: events,
                                isCurrentChapter: chapter == currentChapter,
                                onEventTap: { event in
                                    selectedEvent = event
                                }
                            )
                            .id(chapter)
                        }
                    }
                }
                .padding()
            }
            .onAppear {
                // Scroll to current chapter
                withAnimation {
                    proxy.scrollTo(currentChapter, anchor: .center)
                }
            }
        }
    }

    // MARK: - Story Arc View

    private var storyArcView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Arc Chart
                StoryArcChart(arcs: manager.getArcs(for: bookId), currentChapter: currentChapter)
                    .frame(height: 200)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)

                // Arc Details
                ForEach(manager.getArcs(for: bookId)) { arc in
                    StoryArcCard(
                        arc: arc,
                        isActive: currentChapter >= arc.startChapter && currentChapter <= arc.endChapter
                    )
                    .onTapGesture {
                        selectedArc = arc
                    }
                }

                // Statistics
                let stats = manager.getStatistics(for: bookId)
                StatisticsCard(statistics: stats)
            }
            .padding()
        }
    }

    // MARK: - Chapter View

    private var chapterView: some View {
        List {
            let events = manager.getEvents(for: bookId)
            let chapters = Set(events.map(\.chapterIndex)).sorted()

            ForEach(chapters, id: \.self) { chapter in
                let chapterEvents = events.filter { $0.chapterIndex == chapter }
                Section {
                    ForEach(chapterEvents) { event in
                        CompactEventRow(event: event)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedEvent = event
                            }
                    }
                } header: {
                    HStack {
                        Text("reader.timeline.chapter".localized(with: chapter + 1))
                            .font(.headline)

                        if chapter == currentChapter {
                            Text("reader.timeline.current".localized)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor)
                                .cornerRadius(4)
                        }

                        Spacer()

                        Text("reader.timeline.eventsCount".localized(with: chapterEvents.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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

                    Text("reader.timeline.analyzing".localized)
                        .font(.headline)

                    ProgressView(value: manager.analysisProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)

                    Text("reader.timeline.identifyingPlotEvents".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                    Text("reader.timeline.loading".localized)
                }
            }
            .padding(32)
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}

// MARK: - View Mode

enum TimelineViewMode: String, CaseIterable {
    case timeline
    case arc
    case chapter

    var displayName: String {
        switch self {
        case .timeline: return "Timeline"
        case .arc: return "Story Arc"
        case .chapter: return "By Chapter"
        }
    }

    var icon: String {
        switch self {
        case .timeline: return "line.3.horizontal"
        case .arc: return "chart.line.uptrend.xyaxis"
        case .chapter: return "list.bullet"
        }
    }
}

// MARK: - Chapter Events Section

struct ChapterEventsSection: View {
    let chapter: Int
    let events: [TimelineEvent]
    let isCurrentChapter: Bool
    let onEventTap: (TimelineEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Chapter header
            HStack {
                Text("reader.timeline.chapter".localized(with: chapter + 1))
                    .font(.headline)
                    .foregroundColor(isCurrentChapter ? .accentColor : .primary)

                if isCurrentChapter {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(.accentColor)
                }

                Spacer()

                if let arc = events.first?.arc {
                    Text(arc.displayName)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(arc.color)
                        .cornerRadius(8)
                }
            }
            .padding(.bottom, 16)

            // Events
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                TimelineEventRow(
                    event: event,
                    isLast: index == events.count - 1,
                    onTap: { onEventTap(event) }
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrentChapter ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .padding(.bottom, 16)
    }
}

// MARK: - Timeline Event Row

struct TimelineEventRow: View {
    let event: TimelineEvent
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                // Dot
                ZStack {
                    Circle()
                        .fill(event.type.color.opacity(0.2))
                        .frame(width: event.significance.size + 8, height: event.significance.size + 8)

                    Image(systemName: event.type.icon)
                        .font(.system(size: event.significance.size * 0.6))
                        .foregroundColor(event.type.color)
                }

                // Line
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(event.emotionalTone.emoji)
                }

                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Characters involved
                if !event.involvedCharacterNames.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(event.involvedCharacterNames.joined(separator: ", "))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                // Tags
                HStack(spacing: 8) {
                    // Significance
                    Text(event.significance.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)

                    // Type
                    Text(event.type.displayName)
                        .font(.caption2)
                        .foregroundColor(event.type.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(event.type.color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Story Arc Chart

struct StoryArcChart: View {
    let arcs: [StoryArc]
    let currentChapter: Int

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            // Get chapter range
            let minChapter = arcs.map(\.startChapter).min() ?? 0
            let maxChapter = arcs.map(\.endChapter).max() ?? 1

            ZStack {
                // Background grid
                Path { path in
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)

                // Tension curve
                Path { path in
                    var points: [CGPoint] = []

                    for arc in arcs.sorted(by: { $0.type.order < $1.type.order }) {
                        let startX = width * CGFloat(arc.startChapter - minChapter) / CGFloat(maxChapter - minChapter)
                        let endX = width * CGFloat(arc.endChapter - minChapter) / CGFloat(maxChapter - minChapter)
                        let y = height * (1 - CGFloat(arc.tensionLevel))

                        points.append(CGPoint(x: (startX + endX) / 2, y: y))
                    }

                    if let first = points.first {
                        path.move(to: first)
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: arcs.map(\.type.color),
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                // Arc labels
                ForEach(arcs.sorted(by: { $0.type.order < $1.type.order })) { arc in
                    let startX = width * CGFloat(arc.startChapter - minChapter) / CGFloat(maxChapter - minChapter)
                    let endX = width * CGFloat(arc.endChapter - minChapter) / CGFloat(maxChapter - minChapter)
                    let centerX = (startX + endX) / 2
                    let y = height * (1 - CGFloat(arc.tensionLevel))

                    VStack(spacing: 2) {
                        Circle()
                            .fill(arc.type.color)
                            .frame(width: 10, height: 10)

                        Text(arc.type.chineseName)
                            .font(.caption2)
                            .foregroundColor(arc.type.color)
                    }
                    .position(x: centerX, y: y - 20)
                }

                // Current position indicator
                let currentX = width * CGFloat(currentChapter - minChapter) / CGFloat(maxChapter - minChapter)
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: height)
                    .position(x: currentX, y: height / 2)
            }
        }
    }
}

// MARK: - Story Arc Card

struct StoryArcCard: View {
    let arc: StoryArc
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(arc.type.displayName)
                        .font(.headline)

                    Text(arc.type.chineseName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isActive {
                    Label("reader.timeline.current".localized, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }

                Circle()
                    .fill(arc.type.color)
                    .frame(width: 12, height: 12)
            }

            Text(arc.summary)
                .font(.body)
                .foregroundColor(.secondary)

            HStack {
                Label(arc.chapterRange, systemImage: "book")
                    .font(.caption)

                Spacer()

                // Tension meter
                HStack(spacing: 4) {
                    Text("reader.timeline.tension".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: arc.tensionLevel)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                        .tint(arc.type.color)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Compact Event Row

struct CompactEventRow: View {
    let event: TimelineEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.type.icon)
                .foregroundColor(event.type.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)

                Text(event.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(event.emotionalTone.emoji)
        }
    }
}

// MARK: - Statistics Card

struct StatisticsCard: View {
    let statistics: TimelineStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("reader.timeline.storyStatistics".localized)
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatItem(value: "\(statistics.totalEvents)", label: "reader.timeline.events".localized)
                StatItem(value: "\(statistics.criticalEvents)", label: "reader.timeline.critical".localized)
                StatItem(value: "\(statistics.arcsCount)", label: "reader.timeline.arcs".localized)
            }

            Divider()

            // Events by type
            Text("reader.timeline.eventsByType".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            FlowLayout(spacing: 8) {
                ForEach(Array(statistics.eventsByType.keys), id: \.self) { type in
                    if let count = statistics.eventsByType[type] {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption2)
                            Text("\(type.displayName): \(count)")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(type.color.opacity(0.1))
                        .foregroundColor(type.color)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Event Detail Sheet

struct EventDetailSheet: View {
    let event: TimelineEvent
    let onNavigate: (Int, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: event.type.icon)
                                .font(.title)
                                .foregroundColor(event.type.color)

                            Spacer()

                            Text(event.emotionalTone.emoji)
                                .font(.largeTitle)
                        }

                        Text(event.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let chinese = event.titleChinese {
                            Text(chinese)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Badges
                    HStack(spacing: 8) {
                        TimelineBadge(text: event.type.displayName, color: event.type.color)
                        TimelineBadge(text: event.arc.displayName, color: event.arc.color)
                        TimelineBadge(text: event.significance.displayName, color: .gray)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("reader.timeline.description".localized)
                            .font(.headline)

                        Text(event.description)
                            .font(.body)
                    }

                    // Quote
                    if let quote = event.quote {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reader.timeline.quote".localized)
                                .font(.headline)

                            Text("\"\(quote)\"")
                                .font(.body)
                                .italic()
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }

                    // Characters
                    if !event.involvedCharacterNames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reader.timeline.charactersInvolved".localized)
                                .font(.headline)

                            FlowLayout(spacing: 8) {
                                ForEach(event.involvedCharacterNames, id: \.self) { name in
                                    Text(name)
                                        .font(.subheadline)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(16)
                                }
                            }
                        }
                    }

                    // Location & Time
                    if event.location != nil || event.timestamp != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("reader.timeline.details".localized)
                                .font(.headline)

                            if let location = event.location {
                                Label(location, systemImage: "location")
                                    .font(.subheadline)
                            }

                            if let timestamp = event.timestamp {
                                Label(timestamp, systemImage: "clock")
                                    .font(.subheadline)
                            }
                        }
                    }

                    // Navigate button
                    Button {
                        onNavigate(event.chapterIndex, event.position)
                    } label: {
                        HStack {
                            Image(systemName: "book.pages")
                            Text("reader.timeline.goToPassage".localized)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("reader.timeline.eventDetails".localized)
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

struct TimelineBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(8)
    }
}

// MARK: - Timeline Filter Sheet

struct TimelineFilterSheet: View {
    @Binding var filter: TimelineFilter
    let bookId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("reader.timeline.eventTypes".localized) {
                    ForEach(EventType.allCases, id: \.self) { type in
                        Toggle(isOn: Binding(
                            get: { filter.eventTypes.contains(type) },
                            set: { if $0 { filter.eventTypes.insert(type) } else { filter.eventTypes.remove(type) } }
                        )) {
                            Label(type.displayName, systemImage: type.icon)
                                .foregroundColor(type.color)
                        }
                    }
                }

                Section("reader.timeline.storyArcs".localized) {
                    ForEach(StoryArcType.allCases, id: \.self) { arc in
                        Toggle(isOn: Binding(
                            get: { filter.arcs.contains(arc) },
                            set: { if $0 { filter.arcs.insert(arc) } else { filter.arcs.remove(arc) } }
                        )) {
                            HStack {
                                Text(arc.displayName)
                                Text(arc.chineseName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section("reader.timeline.minimumSignificance".localized) {
                    Picker("reader.timeline.significance".localized, selection: $filter.minSignificance) {
                        ForEach(EventSignificance.allCases, id: \.self) { sig in
                            Text(sig.displayName).tag(sig)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("common.resetFilters".localized) {
                        filter = TimelineFilter()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("reader.timeline.filterEvents".localized)
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
