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
    
    func execute() async -> Bool {
        guard let user = await userRepository.getCurrentUser() else { return false }
        return await repository.isEntitled(userId: user.id)
    }
}



