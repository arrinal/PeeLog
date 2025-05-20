//
//  PeeEventRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

protocol PeeEventRepository {
    func getAllEvents() -> [PeeEvent]
    func getEventsForToday() -> [PeeEvent]
    func addEvent(_ event: PeeEvent)
    func deleteEvent(_ event: PeeEvent)
} 