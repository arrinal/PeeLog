//
//  GetPeeEventsWithLocationUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for fetching events with location data
@MainActor
class GetPeeEventsWithLocationUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute() -> [PeeEvent] {
        return repository.getAllEvents().filter { event in
            event.latitude != nil && event.longitude != nil
        }
    }
} 