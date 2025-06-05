//
//  HistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData

enum TimeRangeFilter: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last3Days = "Last 3 Days"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case custom = "Custom Range"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            return (start, now)
        case .yesterday:
            let start = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .last3Days:
            let start = calendar.date(byAdding: .day, value: -3, to: now)!
            return (start, now)
        case .lastWeek:
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            return (start, now)
        case .lastMonth:
            let start = calendar.date(byAdding: .month, value: -1, to: now)!
            return (start, now)
        case .custom:
            return (calendar.date(byAdding: .day, value: -7, to: now)!, now)
        }
    }
}

struct HistoryView: View {
    @Environment(\.dependencyContainer) private var container
    @Query(sort: \PeeEvent.timestamp, order: .reverse) private var allEvents: [PeeEvent]
    @State private var selectedFilter: TimeRangeFilter = .today
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var customEndDate: Date = Date()
    @State private var selectedEvent: PeeEvent?
    @State private var showingMapSheet = false
    @State private var showingFilterSheet = false
    
    var filteredEvents: [PeeEvent] {
        let range = selectedFilter == .custom ? (customStartDate, customEndDate) : selectedFilter.dateRange
        var result: [PeeEvent] = []
        for event in allEvents {
            if event.timestamp >= range.0 && event.timestamp <= range.1 {
                result.append(event)
            }
        }
        return result
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Filter")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: {
                        showingFilterSheet = true
                    }) {
                        HStack {
                            Text(selectedFilter.rawValue)
                                .foregroundColor(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    showingFilterSheet = true
                }
            }
            .listRowBackground(Color.blue.opacity(0.1))
            
            if filteredEvents.isEmpty {
                Section {
                    Text("No events recorded for this period")
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
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                List {
                    ForEach(TimeRangeFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                            if filter != .custom {
                                showingFilterSheet = false
                            }
                        }) {
                            HStack {
                                Text(filter.rawValue)
                                Spacer()
                                if selectedFilter == filter {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    if selectedFilter == .custom {
                        Section(header: Text("SELECT DATE RANGE")) {
                            DatePicker("Start Date", selection: $customStartDate, in: ...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                            
                            DatePicker("End Date", selection: $customEndDate, in: customStartDate...Date(), displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }
                    }
                }
                .navigationTitle("Filter")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFilterSheet = false
                        }
                    }
                }
            }
        }
        .onChange(of: selectedEvent) { oldValue, newValue in
            if newValue != nil {
                showingMapSheet = true
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
