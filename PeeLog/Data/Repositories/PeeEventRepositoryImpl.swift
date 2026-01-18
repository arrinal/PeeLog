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

    func fetchAllEvents() throws -> [PeeEvent] {
        let descriptor = FetchDescriptor<PeeEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
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
            // Associate with the most recently updated local user if available
            let anyUserDescriptor = FetchDescriptor<User>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
            if let user = try? modelContext.fetch(anyUserDescriptor).first {
                event.userId = user.id
                try modelContext.save()
            }
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
        for incoming in events {
            // Upsert by stable UUID to avoid duplicates
            let fetchAll = try? modelContext.fetch(FetchDescriptor<PeeEvent>())
            let existing = fetchAll?.first(where: { $0.id == incoming.id })
            if let current = existing {
                current.timestamp = incoming.timestamp
                current.notes = incoming.notes
                current.quality = incoming.quality
                current.latitude = incoming.latitude
                current.longitude = incoming.longitude
                current.locationName = incoming.locationName
                // Preserve current.userId if already set; otherwise carry over
                if current.userId == nil { current.userId = incoming.userId }
            } else {
                modelContext.insert(incoming)
            }
        }
        try modelContext.save()
    }
} 
