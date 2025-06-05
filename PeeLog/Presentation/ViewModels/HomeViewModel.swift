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
    
    func loadTodaysEvents(context: ModelContext) {
        todaysEvents = getTodaysPeeEventsUseCase.execute(context: context)
    }
    
    func deleteEvent(at offsets: IndexSet, context: ModelContext) {
        for index in offsets {
            let event = todaysEvents[index]
            deleteEventUseCase.execute(event: event, context: context)
        }
        loadTodaysEvents(context: context)
    }
} 
