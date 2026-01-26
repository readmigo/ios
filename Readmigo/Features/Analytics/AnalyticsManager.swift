import Foundation

@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()

    @Published var overviewStats: OverviewStats?
    @Published var dailyStats: [DailyStats] = []
    @Published var readingTrend: ReadingTrend?
    @Published var vocabularyProgress: VocabularyProgress?
    @Published var readingProgress: ReadingProgress?
    @Published var isLoading = false
    @Published var error: String?

    private init() {}

    // MARK: - Fetch Overview Stats

    func fetchOverviewStats() async {
        do {
            let response: OverviewStatsResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.analyticsOverview
            )
            overviewStats = response.stats
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Daily Stats

    func fetchDailyStats(period: String = "week") async {
        do {
            let response: DailyStatsResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.analyticsDaily)?period=\(period)"
            )
            dailyStats = response.stats
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Reading Trend

    func fetchReadingTrend(period: String = "month") async {
        do {
            let response: ReadingTrendResponse = try await APIClient.shared.request(
                endpoint: "\(APIEndpoints.analyticsReadingTrend)?period=\(period)"
            )
            readingTrend = response.trend
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Vocabulary Progress

    func fetchVocabularyProgress() async {
        do {
            let response: VocabularyProgressResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.analyticsVocabularyProgress
            )
            vocabularyProgress = response.progress
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Fetch Reading Progress

    func fetchReadingProgress() async {
        do {
            let response: ReadingProgressResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.analyticsReadingProgress
            )
            readingProgress = response.progress
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Refresh All

    func refreshAll() async {
        isLoading = true
        error = nil

        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchOverviewStats() }
            group.addTask { await self.fetchDailyStats() }
            group.addTask { await self.fetchReadingTrend() }
            group.addTask { await self.fetchVocabularyProgress() }
            group.addTask { await self.fetchReadingProgress() }
        }

        isLoading = false
    }
}
