//
//  SubscriptionService.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation
import StoreKit

@MainActor
final class SubscriptionService {
    struct Config {
        let monthlyProductId: String
        init(monthlyProductId: String = "com.arrinal.PeeLog.subscription.monthly") {
            self.monthlyProductId = monthlyProductId
        }
    }

    private let config: Config
    private var cachedProduct: Product?

    init(config: Config = .init()) {
        self.config = config
    }

    // MARK: - Product
    func loadMonthlyProduct() async -> Product? {
        if let p = cachedProduct { return p }
        do {
            let products = try await Product.products(for: [config.monthlyProductId])
            let product = products.first
            cachedProduct = product
            return product
        } catch {
            return nil
        }
    }

    // MARK: - Entitlement
    func hasActiveEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == config.monthlyProductId {
                    // Check not revoked/expired
                    if transaction.revocationDate == nil && transaction.expirationDate.map({ $0 > Date() }) ?? true {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Purchase
    func purchaseMonthly() async -> Bool {
        guard let product = await loadMonthlyProduct() else { return false }
        do {
            let result = try await product.purchase(options: [])
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    // MARK: - Restore
    func restorePurchases() async -> Bool {
        do {
            try await AppStore.sync()
            return await hasActiveEntitlement()
        } catch {
            return false
        }
    }
}



