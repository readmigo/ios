import SwiftUI
import SafariServices

/// Main About view with all sections
struct AboutView: View {
    @StateObject private var viewModel = AboutViewModel()
    @EnvironmentObject private var versionManager: VersionManager
    @EnvironmentObject private var authManager: AuthManager

    @State private var showingSafari = false
    @State private var safariURL: URL?
    @State private var showingEmailActionSheet = false
    @State private var showingPhoneActionSheet = false
    @State private var showingMessaging = false
    @State private var showingLoginPrompt = false

    var body: some View {
        NavigationStack {
        List {
            // App Header Section
            Section {
                AppInfoHeaderView()
            }
            .listRowBackground(Color.clear)

            // Version Info Section
            Section {
                // Version
                HStack {
                    Label("about.version".localized, systemImage: "info.circle")
                    Spacer()
                    Text(AppInfo.current.version)
                        .foregroundColor(.secondary)
                }

                // Build Number
                HStack {
                    Label("about.buildNumber".localized, systemImage: "hammer")
                    Spacer()
                    Text(AppInfo.current.build)
                        .foregroundColor(.secondary)
                }

                // Check for Updates - Hidden
                // Button(action: {
                //     Task { await viewModel.checkForUpdate() }
                // }) {
                //     HStack {
                //         Label("about.checkUpdate".localized, systemImage: "arrow.clockwise")
                //
                //         Spacer()
                //
                //         if viewModel.isCheckingUpdate {
                //             ProgressView()
                //                 .scaleEffect(0.8)
                //         } else if let result = viewModel.updateCheckResult {
                //             updateResultView(result)
                //         }
                //     }
                // }
                // .disabled(viewModel.isCheckingUpdate)
            }

            // Feedback Section - Hidden
            // Section(header: Text("about.feedback".localized)) {
            //     Button(action: { viewModel.requestAppReview() }) {
            //         Label("about.rateApp".localized, systemImage: "star.fill")
            //     }
            //     .buttonStyle(.plain)
            //
            //     Button(action: { viewModel.sendEmail() }) {
            //         Label("about.reportProblem".localized, systemImage: "exclamationmark.bubble")
            //     }
            //     .buttonStyle(.plain)
            // }

            // More Section
            Section {
                NavigationLink(destination: AcknowledgmentsView()) {
                    Label("about.acknowledgments".localized, systemImage: "heart")
                }

                NavigationLink(destination: OpenSourceLicensesView()) {
                    Label("about.openSourceLicenses".localized, systemImage: "doc.text.magnifyingglass")
                }
            }

            // Footer Section
            Section {
                FooterView()
            }
            .listRowBackground(Color.clear)
        }
        .navigationTitle("support.about".localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $viewModel.showMailComposer) {
            MailComposerView(
                recipient: ContactData.email,
                subject: "about.feedbackEmailSubject".localized,
                body: viewModel.buildFeedbackEmailBody()
            )
        }
        .sheet(isPresented: $showingSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .alert("common.error".localized, isPresented: $viewModel.showMailError) {
            Button("common.ok".localized, role: .cancel) {}
        } message: {
            Text("about.mailNotAvailable".localized)
        }
        .sheet(isPresented: $showingMessaging) {
            MessageListView()
        }
        .alert("contact.loginRequired".localized, isPresented: $showingLoginPrompt) {
            Button("auth.login".localized) {
                authManager.showLoginPrompt = true
                authManager.loginPromptFeature = "contact.sendMessage".localized
            }
            Button("common.cancel".localized, role: .cancel) {}
        } message: {
            Text("contact.loginRequiredMessage".localized)
        }
        .overlay(alignment: .bottom) {
            if viewModel.showCopiedToast {
                ToastView(message: "contact.copied".localized)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: viewModel.showCopiedToast)
            }
        }
        } // NavigationStack
    }

    @ViewBuilder
    private func updateResultView(_ result: AboutViewModel.UpdateCheckResult) -> some View {
        switch result {
        case .upToDate:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("about.upToDate".localized)
                    .font(.caption)
                    .foregroundColor(.green)
            }
        case .available(let version):
            Button(action: { viewModel.openAppStore() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                    Text("about.updateAvailable".localized)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        case .error:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                Text("common.error".localized)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
}

// MARK: - Footer View

struct FooterView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("about.copyright".localized)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("about.madeWith".localized)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Toast View

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
            .padding(.bottom, 32)
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
