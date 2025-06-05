//
//  PeeEventRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData

class PeeEventRepositoryImpl: PeeEventRepository {
    
    func getAllEvents(context: ModelContext) -> [PeeEvent] {
        do {
            let descriptor = FetchDescriptor<PeeEvent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
            return try context.fetch(descriptor)
        } catch {
            print("Error fetching events: \(error)")
            return []
        }
    }
    
    func getEventsForToday(context: ModelContext) -> [PeeEvent] {
        return getAllEvents(context: context).filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    func addEvent(_ event: PeeEvent, context: ModelContext) {
        do {
            context.insert(event)
            try context.save()
        } catch {
            print("Error adding event: \(error)")
        }
    }
    
    func deleteEvent(_ event: PeeEvent, context: ModelContext) {
        do {
            context.delete(event)
            try context.save()
        } catch {
            print("Error deleting event: \(error)")
        }
    }
} 
