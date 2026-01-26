import SwiftUI
import StoreKit
import MessageUI

@MainActor
class AboutViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isCheckingUpdate = false
    @Published var updateCheckResult: UpdateCheckResult?
    @Published var showMailComposer = false
    @Published var showMailError = false
    @Published var showCopiedToast = false
    @Published var copiedText = ""

    // MARK: - Dependencies

    private let versionManager: VersionManager

    // MARK: - Types

    enum UpdateCheckResult: Equatable {
        case upToDate
        case available(version: String)
        case error(String)
    }

    // MARK: - Initialization

    init(versionManager: VersionManager = .shared) {
        self.versionManager = versionManager
    }

    // MARK: - Version Check

    /// Check for app updates
    func checkForUpdate() async {
        isCheckingUpdate = true
        updateCheckResult = nil

        await versionManager.checkVersion(force: true)

        if let error = versionManager.checkError {
            updateCheckResult = .error(error.localizedDescription)
        } else if versionManager.updateAvailable {
            updateCheckResult = .available(version: versionManager.currentVersion ?? "")
        } else {
            updateCheckResult = .upToDate
        }

        isCheckingUpdate = false

        // Auto-hide the result after 3 seconds
        if updateCheckResult == .upToDate {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if updateCheckResult == .upToDate {
                updateCheckResult = nil
            }
        }
    }

    /// Open App Store for update
    func openAppStore() {
        versionManager.openAppStore()
    }

    // MARK: - App Review

    /// Request app review using StoreKit
    func requestAppReview() {
        if let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    // MARK: - Feedback Email

    /// Check if device can send emails
    var canSendMail: Bool {
        MFMailComposeViewController.canSendMail()
    }

    /// Build feedback email body with device info
    func buildFeedbackEmailBody() -> String {
        let appInfo = AppInfo.current
        let deviceInfo = AboutDeviceInfo.current

        return """

        ----- Device Info -----
        App Version: \(appInfo.version) (Build \(appInfo.build))
        \(deviceInfo.systemVersion)
        Device Model: \(deviceInfo.model)
        Language: \(deviceInfo.language)

        ----- Description -----

        """
    }

    // MARK: - Contact Actions

    /// Send email
    func sendEmail() {
        if canSendMail {
            showMailComposer = true
        } else {
            // Copy email and show error
            copyToClipboard(ContactData.email)
            showMailError = true
        }
    }

    /// Call phone number
    func callPhone() {
        let phoneNumber = ContactData.phone.replacingOccurrences(of: " ", with: "")
        if let url = URL(string: "tel://\(phoneNumber)") {
            UIApplication.shared.open(url)
        }
    }

    /// Copy text to clipboard
    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        copiedText = text
        showCopiedToast = true

        // Hide toast after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCopiedToast = false
        }
    }

    // MARK: - URLs

    /// Privacy Policy URL
    var privacyPolicyURL: URL {
        URL(string: "https://readmigo.app/privacy")!
    }

    /// Terms of Service URL
    var termsOfServiceURL: URL {
        URL(string: "https://readmigo.app/terms")!
    }

    /// User Agreement URL (redirects to Terms of Service)
    var userAgreementURL: URL {
        URL(string: "https://readmigo.app/terms")!
    }
}
