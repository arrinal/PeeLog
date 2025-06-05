//
//  GetAllPeeEventsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftData

// Use case for fetching all events
class GetAllPeeEventsUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(context: ModelContext) -> [PeeEvent] {
        return repository.getAllEvents(context: context)
    }
} 