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
    func execute() async -> Bool { await repository.purchase() }
}



