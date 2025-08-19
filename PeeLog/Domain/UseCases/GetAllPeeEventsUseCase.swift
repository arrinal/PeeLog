//
//  GetAllPeeEventsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for fetching all events
@MainActor
class GetAllPeeEventsUseCase {
    private let repository: PeeEventRepository
    private let userRepository: UserRepository
    
    init(repository: PeeEventRepository, userRepository: UserRepository) {
        self.repository = repository
        self.userRepository = userRepository
    }
    
    func execute() -> [PeeEvent] {
        // Filter events belonging to the current local user to avoid cross-user mixing offline
        let events = repository.getAllEvents()
        // Try to load current user synchronously (best-effort). If unavailable, return all.
        // Since we're @MainActor, we can read a cached currentUser from repository via async hack.
        var currentUserId: UUID?
        let semaphore = DispatchSemaphore(value: 0)
        Task { @MainActor in
            let user = await userRepository.getCurrentUser()
            currentUserId = user?.id
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 0.05)
        guard let uid = currentUserId else { return events }
        return events.filter { $0.userId == nil || $0.userId == uid }
    }
} 