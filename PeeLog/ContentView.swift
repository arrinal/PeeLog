//
//  ContentView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData
import MapKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PeeEvent.timestamp, order: .reverse) private var peeEvents: [PeeEvent]
    @State private var showingAddEventSheet = false
    @State private var selectedEvent: PeeEvent?
    @State private var showingMapSheet = false
    @State private var mapPosition: MapCameraPosition = .automatic
    
    var todaysEvents: [PeeEvent] {
        peeEvents.filter { Calendar.current.isDateInToday($0.timestamp) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Today - Pee events: \(todaysEvents.count)")) {
                    if todaysEvents.isEmpty {
                        Text("No pee events today")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .listRowBackground(Color.blue.opacity(0.1))
                    } else {
                        ForEach(todaysEvents, id: \.id) { event in
                            HStack {
                                // Quality indicator
                                Circle()
                                    .fill(event.quality.color)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                                
                                Text(event.quality.emoji)
                                    .font(.headline)
                                    .padding(.trailing, 2)
                                
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(event.timestamp, style: .time)
                                            .font(.headline)
                                        Text(event.quality.rawValue)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if let notes = event.notes, !notes.isEmpty {
                                        Text(notes)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    if event.hasLocation, let locationName = event.locationName {
                                        Button(action: {
                                            selectedEvent = event
                                            showingMapSheet = true
                                        }) {
                                            HStack {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundColor(.red)
                                                Text(locationName)
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                
                                Spacer()
                                
                                // Small hydration status indicator
                                Text(event.quality.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100, alignment: .trailing)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deleteEvents)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("PeeLog")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "calendar")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddEventSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEventSheet) {
                AddEventView()
            }
            .sheet(isPresented: $showingMapSheet, onDismiss: {
                // Clear selected event when sheet is dismissed
                selectedEvent = nil
            }) {
                LocationMapView(event: selectedEvent)
                    .ignoresSafeArea(.container, edges: .top)
            }
            .onChange(of: selectedEvent) { oldValue, newValue in
                // Only show map sheet if we have a valid event with coordinates
                if let event = newValue, event.hasLocation {
                    showingMapSheet = true
                }
            }
            .background(Color.blue.opacity(0.1).ignoresSafeArea())
        }
    }
    
    private func deleteEvents(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(todaysEvents[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PeeEvent.self, inMemory: true)
}
