import SwiftUI

struct SubscriptionStatusView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @StateObject private var usageTracker = UsageTracker.shared
    @State private var showPaywall = false
    @State private var showCancelConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Current Plan Card
                CurrentPlanCard(
                    state: manager.subscriptionState,
                    tier: manager.currentTier
                )

                // Subscription Details (for paid users)
                if let state = manager.subscriptionState, state.isActive, manager.currentTier != .free {
                    SubscriptionDetailsCard(state: state)
                }

                // Actions
                actionsSection

                // Usage & Features
                if manager.currentTier == .free {
                    UsageProgressSection(usageTracker: usageTracker)
                    LockedFeaturesSection(onUpgrade: { showPaywall = true })
                } else {
                    ProFeaturesSection()
                }

                // Help Section
                HelpSection()

                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("subscription.title".localized)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirmationDialog(
            "subscription.manageSubscription".localized,
            isPresented: $showCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("subscription.openSettings".localized) {
                openSubscriptionSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("subscription.manageInSettings".localized)
        }
        .onAppear {
            Task {
                await usageTracker.syncFromServer()
            }
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if manager.currentTier == .free {
                // Upgrade Button with gradient
                Button(action: { showPaywall = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("subscription.upgradeToPro".localized)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "7C3AED"), Color(hex: "EC4899")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                Text("subscription.unlockFullPotential".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            NavigationLink(destination: RestorePurchasesView()) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("subscription.restorePurchases".localized)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            if manager.isSubscribed {
                Button(action: { showCancelConfirmation = true }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("subscription.manageSubscription".localized)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal)
    }

    private func openSubscriptionSettings() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Current Plan Card

struct CurrentPlanCard: View {
    let state: SubscriptionState?
    let tier: SubscriptionTier

    var body: some View {
        VStack(spacing: 16) {
            // Plan Badge
            HStack {
                Image(systemName: tier.icon)
                    .font(.title)
                    .foregroundColor(tierColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("subscription.currentPlan".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tier.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Spacer()

                if tier != .free {
                    StatusBadge(status: state?.status ?? .active)
                }
            }

            Divider()

            // Quick Stats
            HStack(spacing: 32) {
                if let state = state, state.isActive, tier != .free {
                    VStack {
                        Text(formattedExpiryDate)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(state.willRenew ? "subscription.renews".localized : "subscription.expires".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let productId = state.productId {
                        VStack {
                            Text(periodFromProductId(productId))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("subscription.billing".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    VStack {
                        Text("subscription.limitedAccess".localized)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private var tierColor: Color {
        switch tier {
        case .free: return .gray
        case .pro: return Color(hex: "7C3AED")
        case .premium: return .yellow
        }
    }

    private var formattedExpiryDate: String {
        guard let date = state?.expiresAt else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func periodFromProductId(_ productId: String) -> String {
        if productId.contains("yearly") {
            return "subscription.yearly".localized
        } else if productId.contains("monthly") {
            return "subscription.monthly".localized
        }
        return "Unknown"
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: SubscriptionStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.2))
            .foregroundColor(statusColor)
            .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .active: return .green
        case .expired: return .red
        case .cancelled: return .orange
        case .gracePeriod: return .yellow
        }
    }
}

// MARK: - Subscription Details Card

struct SubscriptionDetailsCard: View {
    let state: SubscriptionState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("subscription.details".localized)
                .font(.headline)

            VStack(spacing: 12) {
                DetailRow(
                    icon: "calendar",
                    title: "subscription.started".localized,
                    value: "subscription.active".localized
                )

                if let expiresAt = state.expiresAt {
                    DetailRow(
                        icon: state.willRenew ? "arrow.clockwise" : "calendar.badge.exclamationmark",
                        title: state.willRenew ? "subscription.nextBilling".localized : "subscription.expires".localized,
                        value: formatDate(expiresAt)
                    )
                }

                DetailRow(
                    icon: "creditcard",
                    title: "subscription.autoRenew".localized,
                    value: state.willRenew ? "subscription.on".localized : "subscription.off".localized
                )

                if let transactionId = state.originalTransactionId {
                    DetailRow(
                        icon: "number",
                        title: "subscription.transactionId".localized,
                        value: String(transactionId.prefix(8)) + "..."
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - Usage Progress Section

struct UsageProgressSection: View {
    @ObservedObject var usageTracker: UsageTracker

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("subscription.yourFeatures".localized)
                .font(.headline)

            // Books
            UsageProgressRow(
                icon: "book.fill",
                title: "subscription.freeBooks".localized,
                current: usageTracker.booksReadCount,
                limit: FeatureLimits.freeBooksLimit
            )

            // AI Explanations
            UsageProgressRow(
                icon: "brain",
                title: "subscription.aiExplanationsToday".localized,
                current: usageTracker.aiCallsToday,
                limit: FeatureLimits.freeAICallsPerDay
            )

            // Vocabulary
            UsageProgressRow(
                icon: "text.book.closed",
                title: "subscription.savedWords".localized,
                current: usageTracker.vocabularyCount,
                limit: FeatureLimits.freeVocabularyLimit
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct UsageProgressRow: View {
    let icon: String
    let title: String
    let current: Int
    let limit: Int

    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(Double(current) / Double(limit), 1.0)
    }

    private var progressColor: Color {
        if progress >= 1.0 {
            return .red
        } else if progress >= 0.8 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text(title)
                    .font(.subheadline)

                Spacer()

                Text("\(current)/\(limit)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(progressColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Locked Features Section

struct LockedFeaturesSection: View {
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("subscription.upgradeToUnlock".localized)
                .font(.headline)

            ForEach(SubscriptionTier.pro.features) { feature in
                Button(action: onUpgrade) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.circle")
                            .foregroundColor(.secondary)
                        Text(feature.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Pro Features Section

struct ProFeaturesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("subscription.proFeatures".localized)
                .font(.headline)

            ForEach(SubscriptionTier.pro.features) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(feature.name)
                        .font(.subheadline)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Help Section

struct HelpSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("subscription.needHelp".localized)
                .font(.headline)

            VStack(spacing: 8) {
                HelpLink(
                    icon: "questionmark.circle",
                    title: "subscription.faq".localized,
                    destination: "https://readmigo.com/faq"
                )

                HelpLink(
                    icon: "envelope",
                    title: "subscription.contactSupport".localized,
                    destination: "mailto:support@readmigo.com"
                )

                HelpLink(
                    icon: "doc.text",
                    title: "subscription.termsOfUse".localized,
                    destination: "https://readmigo.com/terms"
                )

                HelpLink(
                    icon: "hand.raised",
                    title: "subscription.privacyPolicy".localized,
                    destination: "https://readmigo.com/privacy"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct HelpLink: View {
    let icon: String
    let title: String
    let destination: String

    var body: some View {
        Link(destination: URL(string: destination)!) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}
