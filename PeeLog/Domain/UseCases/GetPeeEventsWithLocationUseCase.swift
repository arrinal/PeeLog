//
//  GetPeeEventsWithLocationUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftData

// Use case for fetching events with location data
class GetPeeEventsWithLocationUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(context: ModelContext) -> [PeeEvent] {
        return repository.getAllEvents(context: context).filter { event in
            event.latitude != nil && event.longitude != nil
        }
    }
} 