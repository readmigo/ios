import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var isAnimating = false

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: isAnimating ? geometry.size.width + geometry.size.width * 0.6 : -geometry.size.width * 0.6)
                    .animation(
                        Animation.linear(duration: 1.5)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
                }
            )
            .clipped()
            .onAppear {
                isAnimating = true
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

struct PaywallView: View {
    @StateObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPeriod: SubscriptionPeriod = .yearly
    @State private var isPurchasing = false
    @State private var showError = false

    private let socialProofCount = "50,000+"
    private let appRating = "4.8"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection

                    // Social Proof
                    socialProofSection

                    // Features List
                    featuresSection

                    // Period Selector
                    periodSelectorSection

                    // Subscribe Button
                    subscribeButtonSection

                    // Restore & Terms
                    legalSection

                    Spacer(minLength: 40)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("subscription.goPro".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(manager.error ?? "An error occurred")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Animated sparkles
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    Image(systemName: "sparkle")
                        .font(.title)
                        .foregroundColor(.yellow)
                }
            }
            .padding(.top, 20)

            Text("subscription.unlockPotential".localized)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("subscription.unlimitedAccess".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Social Proof Section

    private var socialProofSection: some View {
        VStack(spacing: 8) {
            Text("subscription.socialProof".localized(with: socialProofCount))
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 2) {
                ForEach(0..<5) { _ in
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
                Text("subscription.rating".localized(with: appRating))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Features Section

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SubscriptionTier.pro.features) { feature in
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(feature.name)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }

    // MARK: - Period Selector Section

    private var periodSelectorSection: some View {
        VStack(spacing: 12) {
            // Yearly Option (Best Value)
            PeriodOptionCard(
                period: .yearly,
                product: manager.yearlyProduct,
                isSelected: selectedPeriod == .yearly,
                isBestValue: true
            ) {
                selectedPeriod = .yearly
            }

            // Monthly Option
            PeriodOptionCard(
                period: .monthly,
                product: manager.monthlyProduct,
                isSelected: selectedPeriod == .monthly,
                isBestValue: false
            ) {
                selectedPeriod = .monthly
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Subscribe Button Section

    private var subscribeButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task { await subscribe() }
            }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        if selectedPeriod == .yearly, let product = manager.yearlyProduct, product.hasFreeTrial {
                            Image(systemName: "gift.fill")
                            Text("subscription.startFreeTrial".localized(with: product.freeTrialDays))
                                .fontWeight(.semibold)
                        } else {
                            Text("subscription.subscribeNow".localized)
                                .fontWeight(.semibold)
                        }
                    }
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
            .disabled(isPurchasing)
            .shimmer()

            // Price after trial
            if selectedPeriod == .yearly, let product = manager.yearlyProduct, product.hasFreeTrial {
                Text("subscription.thenPrice".localized(with: product.displayPrice))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 12) {
            Button("subscription.restorePurchases".localized) {
                Task { await manager.restorePurchases() }
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)

            HStack(spacing: 16) {
                Link("subscription.termsOfUse".localized, destination: URL(string: "https://readmigo.com/terms")!)
                Link("subscription.privacyPolicy".localized, destination: URL(string: "https://readmigo.com/privacy")!)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            // Legal notice
            Group {
                if selectedPeriod == .yearly, let product = manager.yearlyProduct, product.hasFreeTrial {
                    Text("subscription.trialLegalNotice".localized(with: "\(product.displayPrice)/year"))
                } else {
                    Text("subscription.legalNotice".localized)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Actions

    private func subscribe() async {
        let products = selectedPeriod == .yearly ? manager.yearlyProduct : manager.monthlyProduct
        guard let product = products,
              let storeProduct = manager.products.first(where: { $0.id == product.id }) else {
            return
        }

        isPurchasing = true

        do {
            let transaction = try await manager.purchase(storeProduct)
            if transaction != nil {
                dismiss()
            }
        } catch {
            showError = true
        }

        isPurchasing = false
    }
}

// MARK: - Period Option Card

struct PeriodOptionCard: View {
    let period: SubscriptionPeriod
    let product: SubscriptionProduct?
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Best Value Badge
                if isBestValue {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .font(.caption2)
                        Text("subscription.bestValue".localized)
                            .font(.caption2)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "F59E0B"))
                    .cornerRadius(4, corners: [.topLeft, .topRight])
                }

                // Card Content
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(period.displayName)
                                .font(.headline)

                            if let savings = product?.savings {
                                Text(savings)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }

                        if let product = product {
                            if period == .yearly {
                                Text("subscription.perMonth".localized(with: product.pricePerMonth))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("subscription.billedMonthly".localized)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Free trial badge
                        if let product = product, product.hasFreeTrial {
                            HStack(spacing: 4) {
                                Image(systemName: "gift.fill")
                                    .font(.caption2)
                                Text("subscription.includesFreeTrial".localized(with: product.freeTrialDays))
                                    .font(.caption)
                            }
                            .foregroundColor(Color(hex: "8B5CF6"))
                            .padding(.top, 4)
                        }
                    }

                    Spacer()

                    if let product = product {
                        VStack(alignment: .trailing) {
                            Text(product.displayPrice)
                                .font(.title3)
                                .fontWeight(.bold)

                            Text(period == .yearly ? "subscription.perYear".localized : "subscription.perMonth.short".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? .accentColor : .secondary)
                        .font(.title2)
                        .padding(.leading, 8)
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
