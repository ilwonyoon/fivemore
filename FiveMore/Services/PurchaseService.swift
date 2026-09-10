import Foundation
import StoreKit

@MainActor
final class PurchaseService: ObservableObject {
    enum EntitlementState: Equatable {
        case loading
        case locked
        case unlocked
    }

    enum PurchaseError: LocalizedError {
        case failedVerification
        case productUnavailable

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                "The App Store could not verify this purchase."
            case .productUnavailable:
                "The lifetime unlock is temporarily unavailable."
            }
        }
    }

    static let productID = "com.fivemore.app.fullunlock"

    /// The regular price, used only to show a strikethrough when App Store
    /// Connect has a scheduled price change running. Never used to charge —
    /// StoreKit's `displayPrice` is always the authority on what is paid.
    static let regularPriceUSD: Decimal = 4.99

    @Published private(set) var entitlement: EntitlementState = .loading
    @Published private(set) var product: Product?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?

    var isUnlocked: Bool {
        entitlement == .unlocked
    }

    /// True when the store is currently selling below the regular price, so the
    /// paywall can present it as a limited-time offer.
    var isDiscounted: Bool {
        guard let product, product.priceFormatStyle.locale.currency?.identifier == "USD" else {
            return false
        }
        return product.price < Self.regularPriceUSD
    }

    /// The regular price rendered in the store's own format, for strikethrough.
    var regularPriceText: String? {
        guard let product, isDiscounted else { return nil }
        return Self.regularPriceUSD.formatted(product.priceFormatStyle)
    }

    private var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try Self.verified(update)
                    await transaction.finish()
                    await self.refreshEntitlement()
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func prepare() async {
        await loadProduct()
        await refreshEntitlement()
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        var hasVerifiedUnlock = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else { continue }
            guard transaction.productID == Self.productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            hasVerifiedUnlock = true
            break
        }

        entitlement = hasVerifiedUnlock ? .unlocked : .locked
    }

    func purchase() async -> Bool {
        guard let product else {
            errorMessage = PurchaseError.productUnavailable.localizedDescription
            return false
        }

        isWorking = true
        defer { isWorking = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                await refreshEntitlement()
                return isUnlocked
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restore() async -> Bool {
        isWorking = true
        defer { isWorking = false }

        do {
            try await AppStore.sync()
            await refreshEntitlement()
            return isUnlocked
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    nonisolated private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }
}

