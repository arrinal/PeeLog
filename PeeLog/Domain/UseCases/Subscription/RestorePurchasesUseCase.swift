//
//  RestorePurchasesUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
final class RestorePurchasesUseCase {
    private let repository: SubscriptionRepository
    init(repository: SubscriptionRepository) { self.repository = repository }
    func execute() async -> Bool { await repository.restore() }
}



