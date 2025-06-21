//
//  GenerateQualityDistributionUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// Use case for generating quality distribution
@MainActor
class GenerateQualityDistributionUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent], period: TimePeriod, customStartDate: Date? = nil, customEndDate: Date? = nil) -> [QualityDistribution] {
        let filteredEvents = filterEventsByPeriod(events: events, period: period, customStartDate: customStartDate, customEndDate: customEndDate)
        let groupedByQuality = Dictionary(grouping: filteredEvents) { $0.quality }
        
        return PeeQuality.allCases.compactMap { quality in
            let count = groupedByQuality[quality]?.count ?? 0
            return count > 0 ? QualityDistribution(quality: quality, count: count) : nil
        }.sorted { $0.count > $1.count }
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

// Data structure for quality distribution
struct QualityDistribution: Identifiable {
    let id = UUID()
    let quality: PeeQuality
    let count: Int
} 