//
//  MapHistoryViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI
import MapKit
import SwiftData

@MainActor
class MapHistoryViewModel: ObservableObject {
    private let getPeeEventsWithLocationUseCase: GetPeeEventsWithLocationUseCase
    
    @Published var eventsWithLocation: [PeeEvent] = []
    @Published var selectedEvent: PeeEvent?
    @Published var mapCameraPosition: MapCameraPosition = .automatic
    
    init(getPeeEventsWithLocationUseCase: GetPeeEventsWithLocationUseCase) {
        self.getPeeEventsWithLocationUseCase = getPeeEventsWithLocationUseCase
    }
    
    func loadEventsWithLocation() {
        eventsWithLocation = getPeeEventsWithLocationUseCase.execute()
    }
    
    func selectEvent(_ event: PeeEvent) {
        selectedEvent = event
    }
    
    func clearSelectedEvent() {
        selectedEvent = nil
    }
} 