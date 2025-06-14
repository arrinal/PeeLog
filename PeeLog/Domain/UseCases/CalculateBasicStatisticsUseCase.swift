//
//  CalculateBasicStatisticsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// Use case for calculating basic statistics
class CalculateBasicStatisticsUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent]) -> BasicStatistics {
        let totalEvents = events.count
        
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        let thisWeekEvents = events.filter { $0.timestamp >= weekAgo }.count
        
        var averageDaily: Double = 0.0
        var healthScore: Double = 0.0
        
        if !events.isEmpty {
            // Group events by day to count only days with actual events
            let eventsByDay = Dictionary(grouping: events) { event in
                calendar.startOfDay(for: event.timestamp)
            }
            
            // Calculate average based only on days that have events (exclude zero-event days)
            let daysWithEvents = eventsByDay.count
            averageDaily = daysWithEvents > 0 ? Double(totalEvents) / Double(daysWithEvents) : 0.0
            
            // Calculate health score based on quality distribution
            let goodQualities: Set<PeeQuality> = [.clear, .paleYellow, .yellow]
            let goodEvents = events.filter { goodQualities.contains($0.quality) }
            healthScore = totalEvents > 0 ? Double(goodEvents.count) / Double(totalEvents) : 0.0
        }
        
        return BasicStatistics(
            totalEvents: totalEvents,
            thisWeekEvents: thisWeekEvents,
            averageDaily: averageDaily,
            healthScore: healthScore
        )
    }
}

// Data structure for basic statistics
struct BasicStatistics {
    let totalEvents: Int
    let thisWeekEvents: Int
    let averageDaily: Double
    let healthScore: Double
} 