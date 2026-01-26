import SwiftUI

struct AnnualReportView: View {
    @StateObject private var manager = AnnualReportManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var showShareSheet = false
    @State private var shareURL: URL?

    let year: Int

    init(year: Int? = nil) {
        self.year = year ?? Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if manager.isLoading && manager.currentReport == nil {
                loadingView
            } else if manager.isGenerating {
                generatingView
            } else if let report = manager.currentReport {
                reportContent(report)
            } else if let error = manager.error {
                errorView(error)
            } else {
                emptyView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                if manager.currentReport?.isCompleted == true {
                    Button {
                        Task {
                            if let url = await manager.shareReport(year: year) {
                                shareURL = url
                                showShareSheet = true
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = shareURL {
                ShareSheet(items: [url])
            }
        }
        .task {
            await manager.fetchReport(year: year)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your year in review...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Generating View

    private var generatingView: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse)

            VStack(spacing: 8) {
                Text("Generating Your Report")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("We're analyzing your reading data...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ProgressView()
                .scaleEffect(1.2)
        }
        .padding()
    }

    // MARK: - Report Content

    @ViewBuilder
    private func reportContent(_ report: AnnualReport) -> some View {
        TabView(selection: $currentPage) {
            CoverPageView(report: report, year: year)
                .tag(0)

            ReadingOverviewPageView(overview: report.readingOverview)
                .tag(1)

            if report.readingOverview.booksDetail.count > 0 {
                BooksPageView(books: report.readingOverview.booksDetail)
                    .tag(2)
            }

            if report.highlights.hasAnyHighlight {
                HighlightsPageView(highlights: report.highlights)
                    .tag(3)
            }

            RankingPageView(ranking: report.socialRanking)
                .tag(4)

            PreferencesPageView(preferences: report.preferences)
                .tag(5)

            PersonalizationPageView(
                personalization: report.personalization,
                year: year
            )
            .tag(6)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await manager.fetchReport(year: year, forceRefresh: true)
                }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No reading data yet")
                .font(.headline)

            Text("Start reading to generate your annual report")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
