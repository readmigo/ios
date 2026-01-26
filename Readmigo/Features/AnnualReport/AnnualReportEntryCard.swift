import SwiftUI

struct AnnualReportEntryCard: View {
    @StateObject private var manager = AnnualReportManager.shared
    @State private var showReport = false
    @State private var selectedYear: Int

    init() {
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: Date()))
    }

    var body: some View {
        Button {
            showReport = true
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                // Text content
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(String(selectedYear)) Year in Review")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("See your reading highlights")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Year picker or arrow
                if manager.reportHistory.count > 1 {
                    Menu {
                        ForEach(manager.reportHistory, id: \.self) { year in
                            Button {
                                selectedYear = year
                            } label: {
                                if year == selectedYear {
                                    Label("\(String(year))", systemImage: "checkmark")
                                } else {
                                    Text("\(String(year))")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("\(String(selectedYear))")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                    }
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showReport) {
            NavigationStack {
                AnnualReportView(year: selectedYear)
            }
        }
        .task {
            await manager.fetchHistory()
        }
    }
}

// MARK: - Compact Entry Card (for smaller spaces)

struct AnnualReportCompactCard: View {
    @State private var showReport = false
    let year: Int

    init(year: Int? = nil) {
        self.year = year ?? Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        Button {
            showReport = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.blue)

                Text("\(String(year)) Review")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showReport) {
            NavigationStack {
                AnnualReportView(year: year)
            }
        }
    }
}
