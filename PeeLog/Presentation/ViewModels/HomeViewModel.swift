//
//  HomeViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI

class HomeViewModel: ObservableObject {
    private let getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase
    private let deleteEventUseCase: DeletePeeEventUseCase
    
    @Published var todaysEvents: [PeeEvent] = []
    
    init(getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase, deleteEventUseCase: DeletePeeEventUseCase) {
        self.getTodaysPeeEventsUseCase = getTodaysPeeEventsUseCase
        self.deleteEventUseCase = deleteEventUseCase
        
        loadTodaysEvents()
    }
    
    func loadTodaysEvents() {
        todaysEvents = getTodaysPeeEventsUseCase.execute()
    }
    
    func deleteEvent(at offsets: IndexSet) {
        for index in offsets {
            let event = todaysEvents[index]
            deleteEventUseCase.execute(event: event)
        }
        loadTodaysEvents()
    }
} 
