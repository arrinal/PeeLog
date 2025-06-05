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
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: MapHistoryViewModel
    @State private var showingSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $viewModel.mapCameraPosition, selection: $viewModel.selectedEvent) {
                    ForEach(viewModel.eventsWithLocation, id: \.id) { event in
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
                    Text("\(viewModel.eventsWithLocation.count) events on map")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Pee Map")
            .sheet(item: $viewModel.selectedEvent) { event in
                LocationMapView(event: event)
            }
            .onChange(of: viewModel.selectedEvent) { oldValue, newValue in
                if newValue != nil {
                    showingSheet = true
                }
            }
        }
        .onAppear {
            viewModel.loadEventsWithLocation(context: modelContext)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    let repository = PeeEventRepositoryImpl()
    let useCase = GetPeeEventsWithLocationUseCase(repository: repository)
    
    MapHistoryView(viewModel: MapHistoryViewModel(getPeeEventsWithLocationUseCase: useCase))
        .modelContainer(container)
} 