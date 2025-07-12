//
//  AnalyzeHourlyPatternsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// Use case for analyzing hourly patterns
@MainActor
class AnalyzeHourlyPatternsUseCase {
    
    func execute(events: [PeeEvent], period: TimePeriod, customStartDate: Date? = nil, customEndDate: Date? = nil) -> [HourlyData] {
        let filteredEvents = DateFilteringUtility.filterEventsByPeriod(
            events: events, 
            period: period, 
            customStartDate: customStartDate, 
            customEndDate: customEndDate
        )
        let groupedByHour = CalendarUtility.groupEventsByHour(filteredEvents, dateKeyPath: \.timestamp)
        
        return (0...23).map { hour in
            HourlyData(hour: hour, count: groupedByHour[hour]?.count ?? 0)
        }
    }
}

// Data structure for hourly data
struct HourlyData: Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
} 