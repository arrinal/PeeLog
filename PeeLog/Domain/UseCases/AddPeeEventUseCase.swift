//
//  AddPeeEventUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// Use case for adding a new event
@MainActor
class AddPeeEventUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(event: PeeEvent) throws {
        try repository.addEvent(event)
    }
} 