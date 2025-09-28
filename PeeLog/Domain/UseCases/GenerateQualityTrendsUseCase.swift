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
        let now = Date()
        let startDate: Date
        let endDate: Date = now
        
        switch period {
        case .today:
            startDate = CalendarUtility.startOfDay(for: now)
        case .yesterday:
            let yesterdayStart = CalendarUtility.daysAgo(1)
            startDate = CalendarUtility.startOfDay(for: yesterdayStart)
        case .last3Days:
            let threeDaysAgo = CalendarUtility.daysAgo(3)
            startDate = CalendarUtility.startOfDay(for: threeDaysAgo)
        case .lastWeek:
            let weekAgo = CalendarUtility.daysAgo(7)
            startDate = CalendarUtility.startOfDay(for: weekAgo)
        case .lastMonth:
            let monthAgo = CalendarUtility.monthsAgo(1)
            startDate = CalendarUtility.startOfDay(for: monthAgo)
        case .week:
            let sevenDaysAgo = CalendarUtility.daysAgo(7)
            startDate = CalendarUtility.startOfDay(for: sevenDaysAgo)
        case .month:
            let thirtyDaysAgo = CalendarUtility.daysAgo(30)
            startDate = CalendarUtility.startOfDay(for: thirtyDaysAgo)
        case .quarter:
            let ninetyDaysAgo = CalendarUtility.daysAgo(90)
            startDate = CalendarUtility.startOfDay(for: ninetyDaysAgo)
        case .allTime:
            startDate = Date.distantPast
        case .custom:
            startDate = CalendarUtility.startOfDay(for: customStartDate ?? Date.distantPast)
            let customEnd = customEndDate ?? now
            let endOfCustomDay = CalendarUtility.endOfDay(for: customEnd)
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
        let groupedEvents = CalendarUtility.groupEventsByDay(filteredEvents, dateKeyPath: \.timestamp)
        
        return groupedEvents.map { (date, events) in
            let averageQuality = events.map { $0.quality.numericValue }.reduce(0, +) / Double(events.count)
            return QualityTrendPoint(date: date, averageQuality: averageQuality)
        }.sorted { $0.date < $1.date }
    }
}

// Using shared TimePeriod enum from Domain/Entities/TimePeriod.swift

// Data structure for quality trend points
struct QualityTrendPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let averageQuality: Double
} 