//
//  PeeEventRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftData

protocol PeeEventRepository {
    func getAllEvents(context: ModelContext) -> [PeeEvent]
    func getEventsForToday(context: ModelContext) -> [PeeEvent]
    func addEvent(_ event: PeeEvent, context: ModelContext)
    func deleteEvent(_ event: PeeEvent, context: ModelContext)
} 