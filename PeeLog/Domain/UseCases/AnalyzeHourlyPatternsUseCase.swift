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
    
    func execute(events: [PeeEvent]) -> [HourlyData] {
        let groupedByHour = Dictionary(grouping: events) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }
        
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