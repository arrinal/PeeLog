//
//  GetTodaysPeeEventsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for fetching today's events
@MainActor
class GetTodaysPeeEventsUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute() -> [PeeEvent] {
        return repository.getEventsForToday()
    }
} 