//
//  CalculateBasicStatisticsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// Use case for calculating basic statistics
@MainActor
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
            // Only pale yellow is considered optimal hydration
            let optimalEvents = events.filter { $0.quality == .paleYellow }
            let acceptableEvents = events.filter { $0.quality == .clear || $0.quality == .paleYellow }
            let concerningEvents = events.filter { $0.quality == .yellow || $0.quality == .darkYellow || $0.quality == .amber }
            
            // Health score calculation based on medical guidelines
            let optimalScore = Double(optimalEvents.count) / Double(totalEvents) * 1.0
            let acceptableScore = Double(acceptableEvents.count) / Double(totalEvents) * 0.7
            let concerningScore = Double(concerningEvents.count) / Double(totalEvents) * 0.3
            
            healthScore = optimalScore * 0.7 + acceptableScore * 0.2 + concerningScore * 0.1
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