import SwiftUI
import Charts

struct ReadingTrendView: View {
    @StateObject private var manager = AnalyticsManager.shared
    @State private var selectedPeriod = "month"
    @State private var selectedDataPoint: TrendDataPoint?

    let periods = ["week", "month", "year"]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    Text("Week").tag("week")
                    Text("Month").tag("month")
                    Text("Year").tag("year")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Main Chart
                if let trend = manager.readingTrend {
                    VStack(alignment: .leading, spacing: 16) {
                        // Summary
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Total Reading Time")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(formatMinutes(trend.totalMinutes))
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            TrendBadge(trend: trend.trend, percentChange: trend.percentChange)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)

                        // Chart
                        ChartCard(trend: trend, selectedDataPoint: $selectedDataPoint)

                        // Stats Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            MiniStatCard(
                                title: "Daily Average",
                                value: "\(Int(trend.averageMinutes)) min",
                                icon: "chart.bar.fill"
                            )

                            MiniStatCard(
                                title: "Best Day",
                                value: "\(bestDay(from: trend.data)) min",
                                icon: "star.fill"
                            )

                            MiniStatCard(
                                title: "Active Days",
                                value: "\(activeDays(from: trend.data))",
                                icon: "calendar.badge.checkmark"
                            )

                            MiniStatCard(
                                title: "Consistency",
                                value: "\(consistencyPercent(from: trend.data))%",
                                icon: "chart.line.uptrend.xyaxis"
                            )
                        }
                    }
                    .padding(.horizontal)
                } else if manager.isLoading {
                    ProgressView()
                        .padding()
                } else {
                    EmptyStateView(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No Data",
                        message: "Start reading to see your trends!"
                    )
                }

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationTitle("Reading Trend")
        .onChange(of: selectedPeriod) { _, newValue in
            Task {
                await manager.fetchReadingTrend(period: newValue)
            }
        }
        .task {
            await manager.fetchReadingTrend(period: selectedPeriod)
        }
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }

    private func bestDay(from data: [TrendDataPoint]) -> Int {
        data.map { $0.value }.max() ?? 0
    }

    private func activeDays(from data: [TrendDataPoint]) -> Int {
        data.filter { $0.value > 0 }.count
    }

    private func consistencyPercent(from data: [TrendDataPoint]) -> Int {
        guard !data.isEmpty else { return 0 }
        let activeDays = data.filter { $0.value > 0 }.count
        return Int((Double(activeDays) / Double(data.count)) * 100)
    }
}

// MARK: - Chart Card

struct ChartCard: View {
    let trend: ReadingTrend
    @Binding var selectedDataPoint: TrendDataPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let selected = selectedDataPoint {
                HStack {
                    VStack(alignment: .leading) {
                        Text(selected.date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(selected.value) minutes")
                            .font(.headline)
                    }
                    Spacer()
                    Button("Clear") {
                        selectedDataPoint = nil
                    }
                    .font(.caption)
                }
            }

            Chart(trend.data) { point in
                BarMark(
                    x: .value("Date", point.date),
                    y: .value("Minutes", point.value)
                )
                .foregroundStyle(
                    selectedDataPoint?.id == point.id
                        ? Color.accentColor
                        : Color.accentColor.opacity(0.6)
                )
                .cornerRadius(4)
            }
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { value in
                    AxisValueLabel {
                        if let dateString = value.as(String.self) {
                            Text(formatAxisDate(dateString))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let minutes = value.as(Int.self) {
                            Text("\(minutes)m")
                                .font(.caption2)
                        }
                    }
                    AxisGridLine()
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            if let date = proxy.value(atX: location.x, as: String.self) {
                                selectedDataPoint = trend.data.first { $0.date == date }
                            }
                        }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private func formatAxisDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
