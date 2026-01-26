import SwiftUI

// MARK: - Offline Banner View

/// Banner shown when displaying cached data in offline mode
struct OfflineBannerView: View {
    let lastSyncTime: Date?
    var onRefresh: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text("offline.viewingCached".localized)
                    .font(.caption)
                    .fontWeight(.medium)

                if let time = lastSyncTime {
                    Text("offline.lastSync".localized(with: timeAgoString(from: time)))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            Spacer()

            if let onRefresh = onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .padding(6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange)
        .cornerRadius(8)
    }

    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "offline.justNow".localized
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "offline.minutesAgo".localized(with: minutes)
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "offline.hoursAgo".localized(with: hours)
        } else {
            let days = Int(interval / 86400)
            return "offline.daysAgo".localized(with: days)
        }
    }
}

// MARK: - Network Status Banner

/// Banner shown when network status changes
struct NetworkStatusBanner: View {
    @ObservedObject var offlineManager: OfflineManager

    var body: some View {
        if offlineManager.networkStatus == .notConnected {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.caption)
                Text("offline.noConnection".localized)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.red)
        }
    }
}

// MARK: - Data Source Indicator

/// Shows whether data is from cache or network
enum DataSource {
    case network
    case cache(syncedAt: Date?)
    case loading
    case error(String)
}

struct DataSourceIndicator: View {
    let source: DataSource

    var body: some View {
        switch source {
        case .network:
            EmptyView()
        case .cache(let syncedAt):
            HStack(spacing: 4) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.caption2)
                Text("offline.cachedData".localized)
                    .font(.caption2)
                if let time = syncedAt {
                    Text("(\(relativeTimeString(from: time)))")
                        .font(.caption2)
                }
            }
            .foregroundColor(.secondary)
        case .loading:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.6)
                Text("common.loading".localized)
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        case .error(let message):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.caption2)
                Text(message)
                    .font(.caption2)
            }
            .foregroundColor(.red)
        }
    }

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
