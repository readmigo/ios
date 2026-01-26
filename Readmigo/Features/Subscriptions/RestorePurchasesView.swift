import SwiftUI

struct RestorePurchasesView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var restoreState: RestoreState = .idle
    @State private var restoredCount = 0

    enum RestoreState {
        case idle
        case restoring
        case success
        case noSubscriptions
        case error(String)
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 120, height: 120)

                Group {
                    switch restoreState {
                    case .idle:
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.accentColor)
                    case .restoring:
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                    case .noSubscriptions:
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                    case .error:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.red)
                    }
                }
            }

            // Title and Message
            VStack(spacing: 12) {
                Text(titleText)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text(messageText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            // Action Button
            VStack(spacing: 16) {
                switch restoreState {
                case .idle:
                    Button(action: restorePurchases) {
                        Text("Restore Purchases")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                case .restoring:
                    Button(action: {}) {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            Text("Restoring...")
                        }
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(true)

                case .success:
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }

                case .noSubscriptions:
                    VStack(spacing: 12) {
                        Button(action: restorePurchases) {
                            Text("Try Again")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: { dismiss() }) {
                            Text("Go Back")
                                .foregroundColor(.secondary)
                        }
                    }

                case .error:
                    VStack(spacing: 12) {
                        Button(action: restorePurchases) {
                            Text("Try Again")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: contactSupport) {
                            Text("Contact Support")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Restore")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var iconBackgroundColor: Color {
        switch restoreState {
        case .idle: return Color.accentColor.opacity(0.1)
        case .restoring: return Color.accentColor
        case .success: return Color.green.opacity(0.1)
        case .noSubscriptions: return Color.orange.opacity(0.1)
        case .error: return Color.red.opacity(0.1)
        }
    }

    private var titleText: String {
        switch restoreState {
        case .idle: return "Restore Your Purchases"
        case .restoring: return "Restoring..."
        case .success: return "Successfully Restored!"
        case .noSubscriptions: return "No Purchases Found"
        case .error: return "Restore Failed"
        }
    }

    private var messageText: String {
        switch restoreState {
        case .idle:
            return "If you've previously purchased a subscription, you can restore it here. Make sure you're signed in with the same Apple ID."
        case .restoring:
            return "Please wait while we check your purchase history..."
        case .success:
            return restoredCount > 0
                ? "We found and restored \(restoredCount) subscription(s) to your account."
                : "Your subscription has been restored successfully."
        case .noSubscriptions:
            return "We couldn't find any previous purchases associated with your Apple ID. If you believe this is an error, please contact support."
        case .error(let message):
            return message
        }
    }

    private func restorePurchases() {
        restoreState = .restoring

        Task {
            await manager.restorePurchases()

            // Check if restoration was successful
            await MainActor.run {
                if let error = manager.error {
                    restoreState = .error(error)
                } else if manager.isSubscribed {
                    restoredCount = manager.purchasedProductIds.count
                    restoreState = .success
                } else {
                    restoreState = .noSubscriptions
                }
            }
        }
    }

    private func contactSupport() {
        if let url = URL(string: "mailto:support@readmigo.com?subject=Subscription%20Restore%20Issue") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Restore Info View

struct RestoreInfoView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How to Restore")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                InfoStep(
                    number: 1,
                    title: "Sign in with Apple ID",
                    description: "Make sure you're signed in with the same Apple ID used for the original purchase."
                )

                InfoStep(
                    number: 2,
                    title: "Tap Restore",
                    description: "Tap the restore button and wait for the process to complete."
                )

                InfoStep(
                    number: 3,
                    title: "Verify",
                    description: "Your subscription will be automatically activated if found."
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct InfoStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
