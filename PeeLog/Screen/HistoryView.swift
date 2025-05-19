//
//  HistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData
import MapKit

// Define time range filter options for history view
enum TimeRangeFilter: String, CaseIterable, Identifiable {
    case all = "All Time"
    case today = "Today"
    case yesterday = "Yesterday"
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "Last 3 Months"
    case custom = "Custom Range"
    
    var id: String { self.rawValue }
    
    func dateRange() -> (Date?, Date?) {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        switch self {
        case .all:
            return (nil, nil) // No filtering
            
        case .today:
            return (startOfToday, nil)
            
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!
            let endOfYesterday = calendar.date(byAdding: .second, value: -1, to: startOfToday)!
            return (startOfYesterday, endOfYesterday)
            
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (startOfWeek, nil)
            
        case .month:
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            return (startOfMonth, nil)
            
        case .threeMonths:
            let threeMonthsAgo = calendar.date(byAdding: .month, value: -3, to: now)!
            return (threeMonthsAgo, nil)
            
        case .custom:
            return (nil, nil) // Will be handled separately
        }
    }
}

struct HistoryView: View {
    @Query(sort: \PeeEvent.timestamp, order: .reverse) private var allPeeEvents: [PeeEvent]
    
    // Filter state
    @State private var selectedFilter: TimeRangeFilter = .all
    @State private var customStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    @State private var customEndDate: Date = Date()
    @State private var showingFilterSheet = false
    @State private var showingCustomDatePicker = false
    
    // Map view state
    @State private var selectedEvent: PeeEvent?
    @State private var showingMapSheet = false
    
    // Filtered events based on selected time range
    var filteredEvents: [PeeEvent] {
        let (startDate, endDate) = selectedFilter.dateRange()
        
        if selectedFilter == .custom {
            // Use custom date range
            let startOfCustomStart = Calendar.current.startOfDay(for: customStartDate)
            let endOfCustomEnd = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: customEndDate))!
            
            return allPeeEvents.filter { event in
                event.timestamp >= startOfCustomStart && event.timestamp < endOfCustomEnd
            }
        } else if let start = startDate {
            // Filter with start date
            if let end = endDate {
                // Filter with both start and end date
                return allPeeEvents.filter { event in
                    event.timestamp >= start && event.timestamp <= end
                }
            } else {
                // Filter with only start date (to present)
                return allPeeEvents.filter { event in
                    event.timestamp >= start
                }
            }
        } else {
            // No filtering
            return allPeeEvents
        }
    }
    
    // Group events by date
    var groupedEvents: [Date: [PeeEvent]] {
        Dictionary(grouping: filteredEvents) { event in
            Calendar.current.startOfDay(for: event.timestamp)
        }
    }
    
    var sortedDates: [Date] {
        groupedEvents.keys.sorted(by: >)
    }
    
    // Event count for statistics
    var totalFilteredEvents: Int {
        filteredEvents.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter indicator bar
            HStack {
                Button(action: {
                    showingFilterSheet = true
                }) {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(.white)
                        Text("Filter: \(selectedFilter.rawValue)")
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Text("\(totalFilteredEvents) events")
                    .font(.footnote)
                    .foregroundColor(Color(UIColor.label))
                    .padding(.trailing)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground).opacity(0.8))
            
            // Events list
            List {
            if sortedDates.isEmpty {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundColor(Color.blue)
                            Text("No events found")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.label))
                            Text("Try changing your filter settings")
                                .font(.subheadline)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        .padding(.vertical, 40)
                        Spacer()
                    }
                }
            } else {
                ForEach(sortedDates, id: \.self) { date in
                    Section(header: Text(date, style: .date)) {
                    ForEach(groupedEvents[date]!, id: \.id) { event in
                        HStack {
                            // Quality indicator
                            Circle()
                                .fill(event.quality.color)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color(UIColor.separator), lineWidth: 0.5))
                            
                            Text(event.quality.emoji)
                                .font(.headline)
                                .padding(.trailing, 2)
                            
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(event.timestamp, style: .time)
                                        .font(.headline)
                                    Text(event.quality.rawValue)
                                        .font(.subheadline)
                                        .foregroundColor(Color(UIColor.secondaryLabel))
                                }
                                
                                if let notes = event.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if event.hasLocation, let locationName = event.locationName {
                                    Button(action: {
                                        // First set the selectedEvent
                                        selectedEvent = event
                                        // Then allow a small delay to ensure the event is properly set
                                        DispatchQueue.main.async {
                                            showingMapSheet = true
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(.red)
                                            Text(locationName)
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                                .padding(2)
                                                .background(Color(UIColor.tertiarySystemBackground))
                                                .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Small hydration status indicator
                            Text(event.quality.description)
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("History")
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        
        // Filter sheet
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                List {
                    // Navigation design for better visibility in both modes
                    Section(header: Text("TIME RANGE")) {
                        ForEach(TimeRangeFilter.allCases) { filter in
                            Button(action: {
                                self.selectedFilter = filter
                                if filter == .custom {
                                    self.showingCustomDatePicker = true
                                } else {
                                    self.showingFilterSheet = false
                                }
                            }) {
                                HStack {
                                    Text(filter.rawValue)
                                        .foregroundColor(Color(UIColor.label))
                                    Spacer()
                                    if filter == selectedFilter {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .foregroundColor(Color(UIColor.label))
                        }
                    }
                    
                    if selectedFilter == .custom {
                        Section(header: Text("CUSTOM RANGE")) {
                            DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                            DatePicker("End Date", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
                        }
                    }
                    
                    if !filteredEvents.isEmpty {
                        Section {
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Text("\(filteredEvents.count) events")
                                        .font(.headline)
                                        .foregroundColor(Color(UIColor.label))
                                    
                                    if let firstDate = filteredEvents.last?.timestamp,
                                       let lastDate = filteredEvents.first?.timestamp {
                                        Text(firstDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                        Text("to")
                                            .font(.caption2)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                        Text(lastDate, style: .date)
                                            .font(.caption)
                                            .foregroundColor(Color(UIColor.secondaryLabel))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .navigationTitle("Filter History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFilterSheet = false
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Reset") {
                            selectedFilter = .all
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        // Use a new approach with onChange to ensure the sheet only shows when we have valid location data
        .sheet(isPresented: $showingMapSheet, onDismiss: {
            // Make sure to reset the selected event when the sheet is dismissed
            // This ensures that when opening again, the model is freshly loaded
            let tempEvent = selectedEvent
            selectedEvent = nil
            DispatchQueue.main.async {
                selectedEvent = tempEvent
            }
        }) {
            LocationMapView(event: selectedEvent)
                .ignoresSafeArea(.container, edges: .top)
        }
        .onChange(of: selectedEvent) { oldValue, newValue in
            // Verify the selected event actually has location data
            if let event = newValue, !event.hasLocation {
                // If there's no location, don't show the sheet
                showingMapSheet = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: PeeEvent.self, inMemory: true)
}
