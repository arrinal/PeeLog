//
//  GenerateQualityTrendsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// Use case for generating quality trends
@MainActor
class GenerateQualityTrendsUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent], period: TimePeriod) -> [QualityTrendPoint] {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch period {
        case .week:
            // Use start of day 7 days ago to be more inclusive
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            startDate = calendar.startOfDay(for: sevenDaysAgo)
        case .month:
            let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            startDate = calendar.startOfDay(for: thirtyDaysAgo)
        case .quarter:
            let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            startDate = calendar.startOfDay(for: ninetyDaysAgo)
        }
        
        let filteredEvents = events.filter { $0.timestamp >= startDate }
        let groupedByDay = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        
        return groupedByDay.map { date, events in
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
}

// Data structure for quality trend points
struct QualityTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let averageQuality: Double
} 