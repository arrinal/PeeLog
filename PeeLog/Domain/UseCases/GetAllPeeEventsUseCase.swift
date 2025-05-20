//
//  GetAllPeeEventsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for getting all events
class GetAllPeeEventsUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute() -> [PeeEvent] {
        return repository.getAllEvents()
    }
} 