//
//  DeletePeeEventUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftData

// Use case for deleting a pee event
class DeletePeeEventUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(event: PeeEvent, context: ModelContext) {
        repository.deleteEvent(event, context: context)
    }
} 