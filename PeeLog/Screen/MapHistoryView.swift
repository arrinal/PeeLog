//
//  MapHistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData
import MapKit

struct MapHistoryView: View {
    @Query(sort: \PeeEvent.timestamp, order: .reverse) private var allPeeEvents: [PeeEvent]
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedEvent: PeeEvent?
    @State private var showingSheet = false
    
    // Filter only events with location data
    var eventsWithLocation: [PeeEvent] {
        allPeeEvents.filter { $0.hasLocation }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $mapCameraPosition, selection: $selectedEvent) {
                    ForEach(eventsWithLocation, id: \.id) { event in
                        if let coordinate = event.locationCoordinate {
                            Marker(event.locationName ?? "Pee Event", coordinate: coordinate)
                                .tint(event.quality.color)
                        }
                    }
                }
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                
                VStack {
                    Spacer()
                    Text("\(eventsWithLocation.count) events on map")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Pee Map")
            .sheet(item: $selectedEvent) { event in
                LocationMapView(event: event)
            }
            .onChange(of: selectedEvent) { oldValue, newValue in
                if newValue != nil {
                    showingSheet = true
                }
            }
        }
    }
}

#Preview {
    MapHistoryView()
        .modelContainer(for: PeeEvent.self, inMemory: true)
} 