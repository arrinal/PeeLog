//
//  DeletePeeEventUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for deleting an event
class DeletePeeEventUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(event: PeeEvent) {
        repository.deleteEvent(event)
    }
} 