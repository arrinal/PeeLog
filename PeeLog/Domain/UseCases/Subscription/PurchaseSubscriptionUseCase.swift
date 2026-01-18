//
//  PurchaseSubscriptionUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
final class PurchaseSubscriptionUseCase {
    private let repository: SubscriptionRepository
    init(repository: SubscriptionRepository) { self.repository = repository }
    func execute(userId: UUID) async -> PurchaseResult {
        await repository.purchaseAndClaim(userId: userId)
    }
}



