//
//  HistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData

// Using shared TimePeriod enum from Domain/Entities/TimePeriod.swift

struct HistoryView: View {
    @Environment(\.dependencyContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \PeeEvent.timestamp, order: .reverse) private var allEvents: [PeeEvent]
    @State private var selectedFilter: TimePeriod = .today
    @State private var customStartDate: Date = CalendarUtility.daysAgo(7)
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
        ZStack {
            // Adaptive background
            backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Filter Card
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Filter")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                Text(selectedFilter.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingFilterSheet = true
                            }) {
                                HStack(spacing: 6) {
                                    Text("Change")
                                        .font(.system(size: 14, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                        .padding(20)
                        .background(filterCardBackground)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Events Content
            if filteredEvents.isEmpty {
                        // Empty State Card
                        VStack(spacing: 20) {
                            Image(systemName: "calendar.circle")
                                .font(.system(size: 48, weight: .light))
                                .foregroundColor(.blue.opacity(0.6))
                                
                            VStack(spacing: 8) {
                                Text("No events found")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.primary)
                                Text("Try adjusting your filter settings")
                                    .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                        Button(action: {
                                showingFilterSheet = true
                                        }) {
                                            HStack {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Change Filter")
                                }
                                .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.blue)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .background(cardBackground)
                        .padding(.horizontal, 20)
                    } else {
                        // Grouped Events
                        VStack(spacing: 16) {
                            ForEach(groupEventsByDay(), id: \.date) { group in
                                DayGroupCard(
                                    date: group.date,
                                    events: group.events,
                                    onLocationTap: { event in
                                        selectedEvent = event
                                        showingMapSheet = true
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {}
            }
        }
        .sheet(isPresented: $showingMapSheet, onDismiss: {
            selectedEvent = nil
        }) {
            LocationMapView(event: selectedEvent)
                .ignoresSafeArea(.container, edges: .top)
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedFilter: $selectedFilter,
                customStartDate: $customStartDate,
                customEndDate: $customEndDate,
                isPresented: $showingFilterSheet
            )
        }
        .onChange(of: selectedEvent) { oldValue, newValue in
            if let event = newValue, event.hasLocation {
                showingMapSheet = true
            }
        }
    }
    
    // MARK: - Adaptive Colors
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? 
                    Color(red: 0.05, green: 0.05, blue: 0.08) : 
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                colorScheme == .dark ? 
                    Color(red: 0.08, green: 0.08, blue: 0.12) : 
                    Color(red: 0.90, green: 0.95, blue: 0.99)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? 
                    Color.white.opacity(0.05) : 
                    Color.black.opacity(0.06), 
                radius: 8, 
                x: 0, 
                y: 2
            )
    }
    
    private var filterCardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground).opacity(0.8))
            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
    }
    
    private func groupEventsByDay() -> [(date: Date, events: [PeeEvent])] {
        let grouped = CalendarUtility.groupEventsByDay(filteredEvents, dateKeyPath: \.timestamp)
        
        return grouped.map { (date: $0, events: $1) }
            .sorted { $0.date > $1.date }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = CalendarUtility.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
        return formatter.string(from: date)
        }
    }
}

// MARK: - Day Group Card
struct DayGroupCard: View {
    let date: Date
    let events: [PeeEvent]
    let onLocationTap: (PeeEvent) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Date Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedDate(date))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Day Summary Badge
                Text(dayQualitySummary())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(dayQualityColor())
                    )
            }
            
            // Events
            VStack(spacing: 12) {
                ForEach(events.sorted { $0.timestamp > $1.timestamp }) { event in
                    HistoryEventCard(event: event, onLocationTap: onLocationTap)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? 
                        Color.white.opacity(0.05) : 
                        Color.black.opacity(0.06), 
                    radius: 8, 
                    x: 0, 
                    y: 2
                )
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = CalendarUtility.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func dayQualitySummary() -> String {
        guard !events.isEmpty else { return "No data" }
        
        // Based on medical research: pale yellow is optimal, clear is overhydrated
        let summary = QualityFilteringUtility.getQualityDistributionSummary(from: events)
        let optimalCount = summary.optimalCount
        let overhydratedCount = summary.overhydratedCount
        let mildlyDehydratedCount = summary.mildlyDehydratedCount
        let dehydratedCount = summary.dehydratedCount
        let severelyDehydratedCount = summary.severelyDehydratedCount
        let totalCount = events.count
        
        let optimalPercentage = Double(optimalCount) / Double(totalCount)
        let overhydratedPercentage = Double(overhydratedCount) / Double(totalCount)
        let mildlyDehydratedPercentage = Double(mildlyDehydratedCount) / Double(totalCount)
        let dehydratedPercentage = Double(dehydratedCount + severelyDehydratedCount) / Double(totalCount)
        
        // Medical-based assessment with proper categorization
        if optimalPercentage >= 0.7 && dehydratedPercentage <= 0.1 && overhydratedPercentage <= 0.1 {
            return "Excellent hydration"
        } else if optimalPercentage >= 0.5 && dehydratedPercentage <= 0.2 && overhydratedPercentage <= 0.2 {
            return "Good hydration"
        } else if optimalPercentage >= 0.3 && dehydratedPercentage <= 0.4 && overhydratedPercentage <= 0.3 {
            return "Fair hydration"
        } else if dehydratedPercentage >= 0.5 || severelyDehydratedCount > 0 {
            return "Poor hydration - needs attention"
        } else if overhydratedPercentage >= 0.5 {
            return "Overhydration - monitor intake"
        } else {
            return "Mixed hydration levels"
        }
    }
    
    private func dayQualityColor() -> Color {
        guard !events.isEmpty else { return .gray }
        
        let summary = QualityFilteringUtility.getQualityDistributionSummary(from: events)
        let optimalCount = summary.optimalCount
        let overhydratedCount = summary.overhydratedCount
        let mildlyDehydratedCount = summary.mildlyDehydratedCount
        let dehydratedCount = summary.dehydratedCount
        let severelyDehydratedCount = summary.severelyDehydratedCount
        let totalCount = events.count
        
        let optimalPercentage = Double(optimalCount) / Double(totalCount)
        let overhydratedPercentage = Double(overhydratedCount) / Double(totalCount)
        let mildlyDehydratedPercentage = Double(mildlyDehydratedCount) / Double(totalCount)
        let dehydratedPercentage = Double(dehydratedCount + severelyDehydratedCount) / Double(totalCount)
        
        // Color coding based on medical standards
        if optimalPercentage >= 0.7 && dehydratedPercentage <= 0.1 && overhydratedPercentage <= 0.1 {
            return .green // Excellent
        } else if optimalPercentage >= 0.5 && dehydratedPercentage <= 0.2 && overhydratedPercentage <= 0.2 {
            return Color(red: 0.6, green: 0.8, blue: 0.2) // Good (light green)
        } else if optimalPercentage >= 0.3 && dehydratedPercentage <= 0.4 && overhydratedPercentage <= 0.3 {
            return .orange // Fair
        } else if dehydratedPercentage >= 0.5 || severelyDehydratedCount > 0 {
            return .red // Poor
        } else if overhydratedPercentage >= 0.5 {
            return .blue // Overhydration
        } else {
            return Color(red: 0.8, green: 0.6, blue: 0.2) // Mixed (yellowish)
        }
    }
}

// MARK: - History Event Card
struct HistoryEventCard: View {
    let event: PeeEvent
    let onLocationTap: (PeeEvent) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            // Quality Indicator
            ZStack {
                Circle()
                    .fill(event.quality.color)
                    .frame(width: 40, height: 40)
                    .shadow(color: event.quality.color.opacity(0.4), radius: 4, x: 0, y: 2)
                
                Text(event.quality.emoji)
                    .font(.system(size: 16))
            }
            
            // Event Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(event.timestamp, style: .time)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(event.quality.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.blue,
                                            event.quality.color
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if event.hasLocation, let locationName = event.locationName {
                        Button(action: { onLocationTap(event) }) {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                                Text(locationName)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                    }
                    
                    Spacer()
                    
                    Text(event.quality.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(colorScheme == .dark ? 0.3 : 1.0))
                .stroke(Color(.systemGray4).opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Binding var selectedFilter: TimePeriod
    @Binding var customStartDate: Date
    @Binding var customEndDate: Date
    @Binding var isPresented: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Filter Events")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Choose your time range")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        
                        // Filter Options
                        VStack(spacing: 12) {
                            ForEach(TimePeriod.historyFilterOptions, id: \.self) { filter in
                                Button(action: {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        selectedFilter = filter
                                        if filter != .custom {
                                            isPresented = false
                                        }
                                    }
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(filter.rawValue)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                            
                                            if filter != .custom {
                                                Text(dateRangeDescription(for: filter))
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedFilter == filter {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.blue)
                                        } else {
                                            Image(systemName: "circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(.gray.opacity(0.4))
                                        }
                                    }
                                    .padding(20)
                                    .background(filterOptionBackground(isSelected: selectedFilter == filter))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        // Custom Date Range
                        if selectedFilter == .custom {
                            VStack(spacing: 16) {
                                Text("Select Custom Range")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Start Date")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        DatePicker("", selection: $customStartDate, in: ...Date(), displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .accentColor(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("End Date")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.secondary)
                                        DatePicker("", selection: $customEndDate, in: customStartDate...Date(), displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .accentColor(.blue)
                                    }
                                }
                                
                                Button(action: {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        isPresented = false
                                    }
                                }) {
                                    Text("Apply Custom Range")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.blue)
                                                .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                        )
                                }
                                .padding(.top, 8)
                            }
                            .padding(20)
                            .background(cardBackground)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Adaptive Colors
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? 
                    Color(red: 0.05, green: 0.05, blue: 0.08) : 
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                colorScheme == .dark ? 
                    Color(red: 0.08, green: 0.08, blue: 0.12) : 
                    Color(red: 0.90, green: 0.95, blue: 0.99)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? 
                    Color.white.opacity(0.05) : 
                    Color.black.opacity(0.06), 
                radius: 8, 
                x: 0, 
                y: 2
            )
    }
    
    private func filterOptionBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? Color.blue.opacity(colorScheme == .dark ? 0.15 : 0.08) : Color(.systemBackground))
            .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
            .shadow(color: colorScheme == .dark ? Color.white.opacity(0.02) : Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
    
    private func dateRangeDescription(for filter: TimePeriod) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        
        let range = filter.dateRange
        return "\(formatter.string(from: range.start)) - \(formatter.string(from: range.end))"
    }
}

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    NavigationStack {
    HistoryView()
    }
        .modelContainer(container)
} 
