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
    
    func execute(events: [PeeEvent], period: TimePeriod, customStartDate: Date? = nil, customEndDate: Date? = nil) -> [QualityDistribution] {
        let filteredEvents = DateFilteringUtility.filterEventsByPeriod(
            events: events, 
            period: period, 
            customStartDate: customStartDate, 
            customEndDate: customEndDate
        )
        let groupedByQuality = Dictionary(grouping: filteredEvents) { $0.quality }
        
        return PeeQuality.allCases.compactMap { quality in
            let count = groupedByQuality[quality]?.count ?? 0
            return count > 0 ? QualityDistribution(quality: quality, count: count) : nil
        }.sorted { $0.count > $1.count }
    }
}

// Data structure for quality distribution
struct QualityDistribution: Identifiable, Sendable {
    let id = UUID()
    let quality: PeeQuality
    let count: Int
} 