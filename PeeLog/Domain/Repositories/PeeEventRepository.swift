//
//  PeeEventRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

@MainActor
protocol PeeEventRepository {
    func getAllEvents() -> [PeeEvent]
    func getEventsForToday() -> [PeeEvent]
    func addEvent(_ event: PeeEvent) throws
    func deleteEvent(_ event: PeeEvent) throws
    func clearAllEvents() throws
    func addEvents(_ events: [PeeEvent]) throws
} 