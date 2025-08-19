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
        return getAllEvents().filter { CalendarUtility.isDateInToday($0.timestamp) }
    }
    
    func addEvent(_ event: PeeEvent) throws {
        modelContext.insert(event)
        try modelContext.save()
        // Ensure the event is associated with the current local user for offline segregation
        // If userId is empty and we can fetch a current user id, set it.
        if event.userId == nil {
            // Best-effort: load latest non-guest first, else guest
            let userDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.isGuest == false },
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            if let user = try? modelContext.fetch(userDescriptor).first {
                event.userId = user.id
            } else {
                let guestDescriptor = FetchDescriptor<User>(
                    predicate: #Predicate { $0.isGuest == true },
                    sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
                )
                if let guest = try? modelContext.fetch(guestDescriptor).first {
                    event.userId = guest.id
                }
            }
            try modelContext.save()
        }
    }
    
    func deleteEvent(_ event: PeeEvent) throws {
        modelContext.delete(event)
        try modelContext.save()
    }

    func clearAllEvents() throws {
        let descriptor = FetchDescriptor<PeeEvent>()
        let all = try modelContext.fetch(descriptor)
        for e in all { modelContext.delete(e) }
        try modelContext.save()
    }

    func addEvents(_ events: [PeeEvent]) throws {
        for e in events { modelContext.insert(e) }
        try modelContext.save()
    }
} 
