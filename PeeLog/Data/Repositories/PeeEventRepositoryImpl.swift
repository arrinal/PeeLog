//
//  PeeEventRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData

@MainActor
class PeeEventRepositoryImpl: PeeEventRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func getAllEvents() -> [PeeEvent] {
        do {
            let descriptor = FetchDescriptor<PeeEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            return try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching events: \(error)")
            return []
        }
    }
    
    func getEventsForToday() -> [PeeEvent] {
        return getAllEvents().filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    func addEvent(_ event: PeeEvent) throws {
        modelContext.insert(event)
        try modelContext.save()
    }
    
    func deleteEvent(_ event: PeeEvent) throws {
        modelContext.delete(event)
        try modelContext.save()
    }
} 
