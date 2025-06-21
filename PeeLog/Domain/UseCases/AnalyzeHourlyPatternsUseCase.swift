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
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent], period: TimePeriod, customStartDate: Date? = nil, customEndDate: Date? = nil) -> [HourlyData] {
        let filteredEvents = filterEventsByPeriod(events: events, period: period, customStartDate: customStartDate, customEndDate: customEndDate)
        let groupedByHour = Dictionary(grouping: filteredEvents) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }
        
        return (0...23).map { hour in
            HourlyData(hour: hour, count: groupedByHour[hour]?.count ?? 0)
        }
    }
    
    private func filterEventsByPeriod(events: [PeeEvent], period: TimePeriod, customStartDate: Date?, customEndDate: Date?) -> [PeeEvent] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        let endDate: Date = now
        
        switch period {
        case .week:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            startDate = calendar.startOfDay(for: sevenDaysAgo)
        case .month:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            startDate = calendar.startOfDay(for: thirtyDaysAgo)
        case .quarter:
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            startDate = calendar.startOfDay(for: ninetyDaysAgo)
        case .allTime:
            startDate = Date.distantPast
        case .custom:
            startDate = calendar.startOfDay(for: customStartDate ?? Date.distantPast)
            let customEnd = customEndDate ?? now
            let endOfCustomDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: customEnd) ?? customEnd
            return events.filter { $0.timestamp >= startDate && $0.timestamp <= endOfCustomDay }
        }
        
        return events.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
    }
}

// Data structure for hourly data
struct HourlyData: Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
} 