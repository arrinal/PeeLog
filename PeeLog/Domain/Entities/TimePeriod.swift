//
//  TimePeriod.swift
//  PeeLog
//
//  Created by Arrinal S on 25/06/25.
//

import Foundation

// MARK: - Shared Time Period Enum
enum TimePeriod: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case last3Days = "Last 3 Days"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case quarter = "Last 90 Days"
    case allTime = "All Time"
    case custom = "Custom Range"
    
    var displayName: String {
        return self.rawValue
    }
    
    var dateRange: (start: Date, end: Date) {
        let calendar = CalendarUtility.current
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
        case .week:
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            let start = calendar.startOfDay(for: sevenDaysAgo)
            return (start, now)
        case .month:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            let start = calendar.startOfDay(for: thirtyDaysAgo)
            return (start, now)
        case .quarter:
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            let start = calendar.startOfDay(for: ninetyDaysAgo)
            return (start, now)
        case .allTime:
            return (Date.distantPast, now)
        case .custom:
            return (calendar.date(byAdding: .day, value: -7, to: now)!, now)
        }
    }
}

// MARK: - Time Period Categories
extension TimePeriod {
    /// Returns time periods suitable for history filtering
    static var historyFilterOptions: [TimePeriod] {
        return [.today, .yesterday, .last3Days, .lastWeek, .lastMonth, .custom]
    }
    
    /// Returns time periods suitable for statistics analysis
    static var statisticsOptions: [TimePeriod] {
        return [.week, .month, .quarter, .allTime, .custom]
    }
} 