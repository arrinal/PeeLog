//
//  HistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dependencyContainer) private var container
    @Query(sort: \PeeEvent.timestamp, order: .reverse) private var allEvents: [PeeEvent]
    @State private var selectedMonth: Date = Date()
    @State private var selectedEvent: PeeEvent?
    @State private var showingMapSheet = false
    
    var filteredEvents: [PeeEvent] {
        let calendar = Calendar.current
        return allEvents.filter { event in
            calendar.isDate(event.timestamp, equalTo: selectedMonth, toGranularity: .month) &&
            calendar.isDate(event.timestamp, equalTo: selectedMonth, toGranularity: .year)
        }
    }
    
    var body: some View {
        List {
            Section {
                DatePicker("Select Month", selection: $selectedMonth, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .onChange(of: selectedMonth) { oldValue, newValue in
                        // Normalize to first day of month for consistent filtering
                        let calendar = Calendar.current
                        let components = calendar.dateComponents([.year, .month], from: newValue)
                        if let firstDayOfMonth = calendar.date(from: components) {
                            selectedMonth = firstDayOfMonth
                        }
                    }
            }
            .listRowBackground(Color.blue.opacity(0.1))
            
            if filteredEvents.isEmpty {
                Section {
                    Text("No events recorded for this month")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                }
                .listRowBackground(Color.blue.opacity(0.1))
            } else {
                ForEach(groupEventsByDay(), id: \.date) { group in
                    Section(header: Text(formattedDate(group.date))) {
                        ForEach(group.events) { event in
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
                    }
                    .listRowBackground(Color.blue.opacity(0.05))
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("History")
        .sheet(isPresented: $showingMapSheet, onDismiss: {
            selectedEvent = nil
        }) {
            if let event = selectedEvent {
                LocationMapView(event: event)
                    .ignoresSafeArea(.container, edges: .top)
            }
        }
        .onChange(of: selectedEvent) { oldValue, newValue in
            if newValue != nil {
                showingMapSheet = true
            }
        }
        .onAppear {
            // Normalize to first day of month for consistent filtering
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: Date())
            if let firstDayOfMonth = calendar.date(from: components) {
                selectedMonth = firstDayOfMonth
            }
        }
    }
    
    private func groupEventsByDay() -> [EventGroup] {
        let calendar = Calendar.current
        
        // Group events by day
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        
        // Convert to array and sort by date (most recent first)
        return grouped.map { (date, events) in
            EventGroup(date: date, events: events.sorted(by: { $0.timestamp > $1.timestamp }))
        }.sorted(by: { $0.date > $1.date })
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
}

struct EventGroup {
    let date: Date
    let events: [PeeEvent]
}

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    
    HistoryView()
        .modelContainer(container)
} 