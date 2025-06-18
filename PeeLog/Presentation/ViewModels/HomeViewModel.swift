//
//  HomeViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI
import SwiftData

@MainActor
class HomeViewModel: ObservableObject {
    private let getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase
    private let deleteEventUseCase: DeletePeeEventUseCase
    
    @Published var todaysEvents: [PeeEvent] = []
    
    init(getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase, deleteEventUseCase: DeletePeeEventUseCase) {
        self.getTodaysPeeEventsUseCase = getTodaysPeeEventsUseCase
        self.deleteEventUseCase = deleteEventUseCase
    }
    
    func loadTodaysEvents() {
        todaysEvents = getTodaysPeeEventsUseCase.execute()
    }
    
    func deleteEvent(at offsets: IndexSet) {
        for index in offsets {
            let event = todaysEvents[index]
            do {
                try deleteEventUseCase.execute(event: event)
            } catch {
                print("Error deleting event: \(error)")
            }
        }
        loadTodaysEvents()
    }
    
    func deleteEvent(event: PeeEvent) {
        do {
            try deleteEventUseCase.execute(event: event)
        } catch {
            print("Error deleting event: \(error)")
        }
        loadTodaysEvents()
    }
} 
