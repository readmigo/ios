import SwiftUI

struct ForceUpdateView: View {
    @ObservedObject private var versionManager = VersionManager.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "arrow.down.app.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            .padding(.bottom, 32)

            // Title
            Text(LocalizedStringKey("update_required_title"))
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Subtitle
            Text(LocalizedStringKey("update_required_message"))
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            // Version Info
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(LocalizedStringKey("current_version"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(versionManager.appVersion)
                        .font(.headline)
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)

                VStack(spacing: 4) {
                    Text(LocalizedStringKey("latest_version"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(versionManager.currentVersion ?? "-")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            .padding(.top, 24)

            // Release Notes
            if let notes = versionManager.localizedReleaseNotes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey("whats_new"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal)
                .padding(.top, 16)
            }

            Spacer()

            // Update Button
            Button(action: {
                versionManager.openAppStore()
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                    Text(LocalizedStringKey("update_now"))
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(14)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)

            // Retry Check Button (in case of network error)
            if versionManager.checkError != nil {
                Button(action: {
                    Task {
                        await versionManager.checkVersion(force: true)
                    }
                }) {
                    Text(LocalizedStringKey("retry_check"))
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 32)
            } else {
                Color.clear.frame(height: 32)
            }
        }
        .background(
            colorScheme == .dark
                ? Color(.systemBackground)
                : Color(.systemBackground)
        )
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Optional Update Banner

struct UpdateAvailableBanner: View {
    @ObservedObject private var versionManager = VersionManager.shared
    @Binding var isVisible: Bool

    var body: some View {
        if versionManager.shouldShowUpdateBanner && isVisible {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.app")
                    .font(.title3)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey("update_available"))
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("v\(versionManager.currentVersion ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    versionManager.openAppStore()
                }) {
                    Text(LocalizedStringKey("update"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                }

                Button(action: {
                    withAnimation {
                        isVisible = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
            )
            .padding()
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
