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
    private let networkMonitor = NetworkMonitor.shared
    
    @Published var todaysEvents: [PeeEvent] = []
    private var didSetupObservers = false
    
    init(getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase, deleteEventUseCase: DeletePeeEventUseCase, syncCoordinator: SyncCoordinator) {
        self.getTodaysPeeEventsUseCase = getTodaysPeeEventsUseCase
        self.deleteEventUseCase = deleteEventUseCase
        self.syncCoordinator = syncCoordinator
    }
    
    func loadTodaysEvents() {
        todaysEvents = getTodaysPeeEventsUseCase.execute()
        if !didSetupObservers {
            didSetupObservers = true
            NotificationCenter.default.addObserver(forName: .eventsDidSync, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.todaysEvents = self.getTodaysPeeEventsUseCase.execute()
                }
            }
            NotificationCenter.default.addObserver(forName: .eventsStoreWillReset, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.todaysEvents = []
                }
            }
            NotificationCenter.default.addObserver(forName: .eventsStoreDidReset, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.todaysEvents = self.getTodaysPeeEventsUseCase.execute()
                }
            }
        }
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

    func refreshOnConnectivityChange(isOnline: Bool) {
        Task { @MainActor in
            // Always read from local store; ContentView handles syncing when online
            todaysEvents = getTodaysPeeEventsUseCase.execute()
        }
    }
} 
