import Foundation
import SwiftUI

@MainActor
class AnnualReportManager: ObservableObject {
    static let shared = AnnualReportManager()

    // MARK: - Published Properties

    @Published var currentReport: AnnualReport?
    @Published var reportHistory: [Int] = []
    @Published var currentYear: Int = Calendar.current.component(.year, from: Date())
    @Published var selectedYear: Int
    @Published var isLoading = false
    @Published var isGenerating = false
    @Published var error: String?
    @Published var shareUrl: String?

    // MARK: - Cache

    private var reportCache: [Int: AnnualReport] = [:]
    private let cacheKey = "annual_report_cache"
    private let historyCacheKey = "annual_report_history"

    // MARK: - Init

    private init() {
        selectedYear = Calendar.current.component(.year, from: Date())
        loadCachedHistory()
    }

    // MARK: - Cache Management

    private func loadCachedHistory() {
        if let data = UserDefaults.standard.data(forKey: historyCacheKey),
           let cached = try? JSONDecoder().decode(AnnualReportHistoryResponse.self, from: data) {
            reportHistory = cached.years
            currentYear = cached.currentYear
        }
    }

    private func cacheHistory(_ response: AnnualReportHistoryResponse) {
        if let data = try? JSONEncoder().encode(response) {
            UserDefaults.standard.set(data, forKey: historyCacheKey)
        }
    }

    // MARK: - Fetch Report

    func fetchReport(year: Int, forceRefresh: Bool = false) async {
        // Return cached if available and not forcing refresh
        if !forceRefresh, let cached = reportCache[year], cached.isCompleted {
            currentReport = cached
            return
        }

        isLoading = true
        error = nil

        do {
            let report: AnnualReport = try await APIClient.shared.request(
                endpoint: APIEndpoints.annualReport(year)
            )

            currentReport = report
            if report.isCompleted {
                reportCache[year] = report
            }

            // If still generating, start polling
            if report.isGenerating {
                isGenerating = true
                await pollForCompletion(year: year)
            }
        } catch {
            self.error = "Failed to load report: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Poll for Completion

    private func pollForCompletion(year: Int) async {
        var attempts = 0
        let maxAttempts = 30 // 30 seconds max

        while attempts < maxAttempts && isGenerating {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            do {
                let status: AnnualReportStatusResponse = try await APIClient.shared.request(
                    endpoint: APIEndpoints.annualReportStatus(year)
                )

                if status.statusEnum == .completed {
                    isGenerating = false
                    await fetchReport(year: year, forceRefresh: true)
                    break
                } else if status.statusEnum == .failed {
                    isGenerating = false
                    error = "Report generation failed"
                    break
                }
            } catch {
                // Continue polling on error
            }

            attempts += 1
        }

        if attempts >= maxAttempts {
            isGenerating = false
            error = "Report generation timed out"
        }
    }

    // MARK: - Fetch History

    func fetchHistory() async {
        do {
            let response: AnnualReportHistoryResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.annualReportHistory
            )

            reportHistory = response.years
            currentYear = response.currentYear
            cacheHistory(response)
        } catch {
            self.error = "Failed to load history: \(error.localizedDescription)"
        }
    }

    // MARK: - Regenerate Report

    func regenerateReport(year: Int) async {
        isLoading = true
        isGenerating = true
        error = nil

        // Clear cache for this year
        reportCache.removeValue(forKey: year)

        do {
            let report: AnnualReport = try await APIClient.shared.request(
                endpoint: APIEndpoints.annualReportRegenerate(year),
                method: .post
            )

            currentReport = report

            if report.isGenerating {
                await pollForCompletion(year: year)
            } else if report.isCompleted {
                reportCache[year] = report
                isGenerating = false
            }
        } catch {
            self.error = "Failed to regenerate report: \(error.localizedDescription)"
            isGenerating = false
        }

        isLoading = false
    }

    // MARK: - Create Share Page

    func createSharePage(year: Int) async -> String? {
        isLoading = true
        error = nil

        do {
            let response: SharePageResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.annualReportSharePage(year),
                method: .post
            )

            shareUrl = response.url
            isLoading = false
            return response.url
        } catch {
            self.error = "Failed to create share page: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }

    // MARK: - Record Share

    func recordShare(year: Int, platform: String) async {
        let request = ShareLogRequest(platform: platform)

        do {
            let _: EmptyResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.annualReportShare(year),
                method: .post,
                body: request
            )
        } catch {
            // Silently fail - sharing should still work even if logging fails
            print("[AnnualReportManager] Failed to log share: \(error.localizedDescription)")
        }
    }

    // MARK: - Share

    func shareReport(year: Int) async -> URL? {
        guard let urlString = await createSharePage(year: year),
              let url = URL(string: urlString) else {
            return nil
        }

        return url
    }

    // MARK: - Select Year

    func selectYear(_ year: Int) async {
        selectedYear = year
        await fetchReport(year: year)
    }

    // MARK: - Refresh

    func refresh() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchHistory() }
            group.addTask { await self.fetchReport(year: self.selectedYear, forceRefresh: true) }
        }
    }

    // MARK: - Clear Cache

    func clearCache() {
        reportCache.removeAll()
        currentReport = nil
        reportHistory = []
        shareUrl = nil
    }
}
