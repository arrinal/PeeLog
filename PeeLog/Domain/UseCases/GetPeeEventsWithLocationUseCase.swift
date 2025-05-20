//
//  GetPeeEventsWithLocationUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for events with location
class GetPeeEventsWithLocationUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute() -> [PeeEvent] {
        return repository.getAllEvents().filter { $0.hasLocation }
    }
} 