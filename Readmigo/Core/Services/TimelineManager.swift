import Foundation
import Combine

@MainActor
class TimelineManager: ObservableObject {
    static let shared = TimelineManager()

    // MARK: - Published Properties

    @Published var events: [String: [TimelineEvent]] = [:] // bookId -> events
    @Published var arcs: [String: [StoryArc]] = [:] // bookId -> arcs
    @Published var chapterSummaries: [String: [ChapterSummary]] = [:] // bookId -> summaries
    @Published var plotThreads: [String: [PlotThread]] = [:] // bookId -> threads
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0
    @Published var error: String?

    // MARK: - Private Properties

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let cacheKey = "timelineCache"

    // MARK: - Initialization

    private init() {
        loadFromCache()
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? decoder.decode(TimelineCache.self, from: data) {
            events = cached.events
            arcs = cached.arcs
            chapterSummaries = cached.chapterSummaries
            plotThreads = cached.plotThreads
        }
    }

    private func saveToCache() {
        let cache = TimelineCache(
            events: events,
            arcs: arcs,
            chapterSummaries: chapterSummaries,
            plotThreads: plotThreads
        )
        if let data = try? encoder.encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Fetch Timeline

    func fetchTimeline(bookId: String, forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = events[bookId], !cached.isEmpty {
            return
        }

        isLoading = true
        error = nil

        do {
            let response: TimelineResponse = try await APIClient.shared.request(
                endpoint: "/books/\(bookId)/timeline"
            )

            events[bookId] = response.events
            arcs[bookId] = response.arcs
            saveToCache()
        } catch {
            self.error = error.localizedDescription

            // Try AI analysis if no existing data
            if events[bookId]?.isEmpty ?? true {
                await analyzeTimeline(bookId: bookId)
            }
        }

        isLoading = false
    }

    // MARK: - AI Timeline Analysis

    func analyzeTimeline(bookId: String, detailLevel: TimelineDetailLevel = .standard) async {
        isAnalyzing = true
        analysisProgress = 0
        error = nil

        do {
            let request = TimelineAnalysisRequest(
                bookId: bookId,
                forceReanalyze: true,
                detailLevel: detailLevel
            )

            let response: TimelineResponse = try await APIClient.shared.request(
                endpoint: "/ai/analyze-timeline",
                method: .post,
                body: request
            )

            events[bookId] = response.events
            arcs[bookId] = response.arcs
            saveToCache()
            analysisProgress = 1.0
        } catch {
            self.error = "Timeline analysis failed: \(error.localizedDescription)"
        }

        isAnalyzing = false
    }

    // MARK: - Get Events

    func getEvents(for bookId: String) -> [TimelineEvent] {
        (events[bookId] ?? []).sorted { $0.chapterIndex < $1.chapterIndex }
    }

    func getEvents(for bookId: String, chapter: Int) -> [TimelineEvent] {
        getEvents(for: bookId).filter { $0.chapterIndex == chapter }
    }

    func getFilteredEvents(for bookId: String, filter: TimelineFilter) -> [TimelineEvent] {
        getEvents(for: bookId).filter { filter.matches($0) }
    }

    func getCriticalEvents(for bookId: String) -> [TimelineEvent] {
        getEvents(for: bookId).filter { $0.significance == .critical }
    }

    // MARK: - Get Arcs

    func getArcs(for bookId: String) -> [StoryArc] {
        (arcs[bookId] ?? []).sorted { $0.type.order < $1.type.order }
    }

    func getCurrentArc(for bookId: String, chapter: Int) -> StoryArc? {
        getArcs(for: bookId).first { chapter >= $0.startChapter && chapter <= $0.endChapter }
    }

    // MARK: - Get Chapter Summaries

    func getChapterSummary(for bookId: String, chapter: Int) -> ChapterSummary? {
        chapterSummaries[bookId]?.first { $0.chapterIndex == chapter }
    }

    // MARK: - Get Plot Threads

    func getPlotThreads(for bookId: String) -> [PlotThread] {
        plotThreads[bookId] ?? []
    }

    func getActiveThreads(for bookId: String, chapter: Int) -> [PlotThread] {
        getPlotThreads(for: bookId).filter { thread in
            thread.startChapter <= chapter && (thread.endChapter ?? Int.max) >= chapter
        }
    }

    // MARK: - Timeline Statistics

    func getStatistics(for bookId: String) -> TimelineStatistics {
        let allEvents = getEvents(for: bookId)
        let allArcs = getArcs(for: bookId)

        let eventsByType = Dictionary(grouping: allEvents, by: { $0.type })
        let eventsByArc = Dictionary(grouping: allEvents, by: { $0.arc })

        let avgTension = allArcs.isEmpty ? 0 : allArcs.map(\.tensionLevel).reduce(0, +) / Double(allArcs.count)

        return TimelineStatistics(
            totalEvents: allEvents.count,
            criticalEvents: allEvents.filter { $0.significance == .critical }.count,
            arcsCount: allArcs.count,
            eventsByType: eventsByType.mapValues(\.count),
            eventsByArc: eventsByArc.mapValues(\.count),
            averageTensionLevel: avgTension
        )
    }

    // MARK: - Clear Cache

    func clearCache(for bookId: String? = nil) {
        if let bookId = bookId {
            events.removeValue(forKey: bookId)
            arcs.removeValue(forKey: bookId)
            chapterSummaries.removeValue(forKey: bookId)
            plotThreads.removeValue(forKey: bookId)
        } else {
            events.removeAll()
            arcs.removeAll()
            chapterSummaries.removeAll()
            plotThreads.removeAll()
        }
        saveToCache()
    }
}

// MARK: - Cache Structure

private struct TimelineCache: Codable {
    let events: [String: [TimelineEvent]]
    let arcs: [String: [StoryArc]]
    let chapterSummaries: [String: [ChapterSummary]]
    let plotThreads: [String: [PlotThread]]
}

// MARK: - Statistics

struct TimelineStatistics {
    let totalEvents: Int
    let criticalEvents: Int
    let arcsCount: Int
    let eventsByType: [EventType: Int]
    let eventsByArc: [StoryArcType: Int]
    let averageTensionLevel: Double
}
