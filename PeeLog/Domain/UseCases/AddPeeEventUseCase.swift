//
//  AddPeeEventUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftData

// Use case for adding a new event
class AddPeeEventUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(event: PeeEvent, context: ModelContext) {
        repository.addEvent(event, context: context)
    }
} 