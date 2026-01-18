//
//  SubscriptionRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
final class SubscriptionRepositoryImpl: SubscriptionRepository {
    private let service: SubscriptionService

    init(service: SubscriptionService = SubscriptionService()) {
        self.service = service
    }

    func currentEntitlementStatus(userId: UUID) async -> EntitlementStatus {
        return await service.hasActiveEntitlement() ? .entitled : .notEntitled
    }

    func purchaseAndClaim(userId: UUID) async -> PurchaseResult {
        let purchased = await service.purchaseMonthly()
        return purchased ? .success : .failed
    }

    func restoreAndClaim(userId: UUID) async -> PurchaseResult {
        let restored = await service.restorePurchases()
        return restored ? .success : .failed
    }
}



