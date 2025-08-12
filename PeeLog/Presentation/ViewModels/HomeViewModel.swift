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
    private let syncCoordinator: SyncCoordinator
    
    @Published var todaysEvents: [PeeEvent] = []
    
    init(getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase, deleteEventUseCase: DeletePeeEventUseCase, syncCoordinator: SyncCoordinator) {
        self.getTodaysPeeEventsUseCase = getTodaysPeeEventsUseCase
        self.deleteEventUseCase = deleteEventUseCase
        self.syncCoordinator = syncCoordinator
    }
    
    func loadTodaysEvents() {
        todaysEvents = getTodaysPeeEventsUseCase.execute()
    }
    
    func deleteEvent(at offsets: IndexSet) {
        for index in offsets {
            let event = todaysEvents[index]
            do {
                try deleteEventUseCase.execute(event: event)
                Task { try? await syncCoordinator.syncDeleteSingleEvent(event) }
            } catch {
                print("Error deleting event: \(error)")
            }
        }
        loadTodaysEvents()
    }
    
    func deleteEvent(event: PeeEvent) {
        do {
            try deleteEventUseCase.execute(event: event)
            Task { try? await syncCoordinator.syncDeleteSingleEvent(event) }
        } catch {
            print("Error deleting event: \(error)")
        }
        loadTodaysEvents()
    }
} 
