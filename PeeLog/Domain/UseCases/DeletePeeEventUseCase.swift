//
//  DeletePeeEventUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for deleting a pee event
@MainActor
class DeletePeeEventUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(event: PeeEvent) throws {
        try repository.deleteEvent(event)
    }
} 