import Foundation
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    // MARK: - Published Properties

    @Published var products: [Product] = []
    @Published var subscriptionState: SubscriptionState?
    @Published var purchasedProductIds: Set<String> = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Product IDs (Pro-only, Premium reserved for future)

    private let productIds = [
        "com.readmigo.pro.monthly",
        "com.readmigo.pro.yearly"
    ]

    // Product ID constants
    static let proMonthlyId = "com.readmigo.pro.monthly"
    static let proYearlyId = "com.readmigo.pro.yearly"

    // MARK: - Transaction Listener

    private var updateListenerTask: Task<Void, Error>?

    // MARK: - Init

    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await loadProducts()
            await refreshSubscriptionStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Computed Properties

    var currentTier: SubscriptionTier {
        subscriptionState?.tier ?? .free
    }

    var isSubscribed: Bool {
        subscriptionState?.isActive == true && currentTier != .free
    }

    var proProducts: [SubscriptionProduct] {
        products
            .filter { $0.id.contains("pro") }
            .map { mapToSubscriptionProduct($0, tier: .pro) }
    }

    /// Monthly Pro subscription product
    var monthlyProduct: SubscriptionProduct? {
        guard let product = products.first(where: { $0.id == Self.proMonthlyId }) else {
            return nil
        }
        return mapToSubscriptionProduct(product, tier: .pro)
    }

    /// Yearly Pro subscription product (includes 7-day free trial)
    var yearlyProduct: SubscriptionProduct? {
        guard let product = products.first(where: { $0.id == Self.proYearlyId }) else {
            return nil
        }
        return mapToSubscriptionProduct(product, tier: .pro)
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoading = true
        error = nil

        do {
            products = try await Product.products(for: productIds)
                .sorted { $0.price < $1.price }
        } catch {
            self.error = "Failed to load products: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        error = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)

                // Verify with backend
                await verifyWithBackend(transaction: transaction, productId: product.id)

                await transaction.finish()
                isLoading = false
                return transaction

            case .pending:
                isLoading = false
                throw PurchaseError.pending

            case .userCancelled:
                isLoading = false
                return nil

            @unknown default:
                isLoading = false
                return nil
            }
        } catch {
            isLoading = false
            self.error = error.localizedDescription
            throw error
        }
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        isLoading = true
        error = nil

        do {
            try await AppStore.sync()

            // Check current entitlements
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    purchasedProductIds.insert(transaction.productID)
                    await verifyWithBackend(transaction: transaction, productId: transaction.productID)
                }
            }

            // Also call backend restore endpoint
            let response: RestorePurchasesResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.subscriptionsRestore,
                method: .post
            )

            if let subscription = response.subscription {
                subscriptionState = subscription
            }

        } catch {
            self.error = "Failed to restore purchases: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Refresh Status

    func refreshSubscriptionStatus() async {
        do {
            let response: SubscriptionStatusResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.subscriptionsStatus
            )
            subscriptionState = response.subscription
        } catch {
            // Silently fail - user might not be subscribed
        }
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.verifyWithBackend(transaction: transaction, productId: transaction.productID)
                    await transaction.finish()
                } catch {
                    // Handle verification failure
                }
            }
        }
    }

    // MARK: - Verify Transaction

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.unverified
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Backend Verification

    private func verifyWithBackend(transaction: StoreKit.Transaction, productId: String) async {
        // Get the receipt data
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              let receiptData = try? Data(contentsOf: appStoreReceiptURL) else {
            return
        }

        let receiptString = receiptData.base64EncodedString()

        let request = VerifyReceiptRequest(
            receiptData: receiptString,
            productId: productId,
            transactionId: String(transaction.id)
        )

        do {
            let response: VerifyReceiptResponse = try await APIClient.shared.request(
                endpoint: APIEndpoints.subscriptionsVerify,
                method: .post,
                body: request
            )

            if let subscription = response.subscription {
                await MainActor.run {
                    self.subscriptionState = subscription
                    self.purchasedProductIds.insert(productId)
                }
            }
        } catch {
            // Log error but don't fail the purchase
            print("Backend verification failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func mapToSubscriptionProduct(_ product: Product, tier: SubscriptionTier) -> SubscriptionProduct {
        let period: SubscriptionPeriod = product.id.contains("yearly") ? .yearly : .monthly

        // Extract free trial information from subscription info
        var hasFreeTrial = false
        var freeTrialDays = 0

        if let subscriptionInfo = product.subscription {
            // Check for introductory offer (free trial)
            if let introOffer = subscriptionInfo.introductoryOffer {
                if introOffer.paymentMode == .freeTrial {
                    hasFreeTrial = true
                    // Calculate trial days based on period
                    switch introOffer.period.unit {
                    case .day:
                        freeTrialDays = introOffer.period.value
                    case .week:
                        freeTrialDays = introOffer.period.value * 7
                    case .month:
                        freeTrialDays = introOffer.period.value * 30
                    case .year:
                        freeTrialDays = introOffer.period.value * 365
                    @unknown default:
                        freeTrialDays = 7 // Default to 7 days
                    }
                }
            }
        }

        return SubscriptionProduct(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            price: product.price,
            displayPrice: product.displayPrice,
            period: period,
            tier: tier,
            hasFreeTrial: hasFreeTrial,
            freeTrialDays: freeTrialDays
        )
    }
}

// MARK: - Purchase Error

enum PurchaseError: Error, LocalizedError {
    case pending
    case unverified
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .pending:
            return "Purchase is pending approval"
        case .unverified:
            return "Purchase could not be verified"
        case .failed(let message):
            return message
        }
    }
}
