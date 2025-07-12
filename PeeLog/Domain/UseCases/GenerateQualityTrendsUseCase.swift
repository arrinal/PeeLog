//
//  GenerateQualityTrendsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// MARK: - Date Filtering Utility
struct DateFilteringUtility {
    static func filterEventsByPeriod(events: [PeeEvent], period: TimePeriod, customStartDate: Date?, customEndDate: Date?) -> [PeeEvent] {
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

// MARK: - Generate Quality Trends Use Case
class GenerateQualityTrendsUseCase {
    func execute(events: [PeeEvent], period: TimePeriod, customStartDate: Date?, customEndDate: Date?) -> [QualityTrendPoint] {
        let filteredEvents = DateFilteringUtility.filterEventsByPeriod(
            events: events, 
            period: period, 
            customStartDate: customStartDate, 
            customEndDate: customEndDate
        )
        
        guard !filteredEvents.isEmpty else { return [] }
        
        // Group events by day and calculate average quality for each day
        let calendar = Calendar.current
        let groupedEvents = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        
        return groupedEvents.map { (date, events) in
            let averageQuality = events.map { $0.quality.numericValue }.reduce(0, +) / Double(events.count)
            return QualityTrendPoint(date: date, averageQuality: averageQuality)
        }.sorted { $0.date < $1.date }
    }
}

// Time period enum
enum TimePeriod: String, CaseIterable {
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case quarter = "Last 90 Days"
    case allTime = "All Time"
    case custom = "Custom Range"
}

// Data structure for quality trend points
struct QualityTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let averageQuality: Double
} 