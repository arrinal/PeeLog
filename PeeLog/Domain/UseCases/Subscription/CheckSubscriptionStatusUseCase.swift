//
//  CheckSubscriptionStatusUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
final class CheckSubscriptionStatusUseCase {
    private let repository: SubscriptionRepository
    private let userRepository: UserRepository
    
    init(repository: SubscriptionRepository, userRepository: UserRepository) {
        self.repository = repository
        self.userRepository = userRepository
    }
    
    func execute() async -> EntitlementStatus {
        guard let user = await userRepository.getCurrentUser() else { return .notEntitled }
        return await repository.currentEntitlementStatus(userId: user.id)
    }
}



