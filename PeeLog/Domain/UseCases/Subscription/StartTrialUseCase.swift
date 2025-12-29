//
//  StartTrialUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
final class StartTrialUseCase {
    private let repository: SubscriptionRepository
    private let userRepository: UserRepository
    
    init(repository: SubscriptionRepository, userRepository: UserRepository) {
        self.repository = repository
        self.userRepository = userRepository
    }
    
    func execute() async {
        guard let user = await userRepository.getCurrentUser() else { return }
        repository.startTrialIfEligible(userId: user.id)
    }
}



