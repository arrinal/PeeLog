//
//  GenerateWeeklyDataUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation
import SwiftUI

// Use case for generating weekly data
class GenerateWeeklyDataUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent]) -> [WeeklyData] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let dayOfWeek = calendar.component(.weekday, from: date)
            let dayName = calendar.shortWeekdaySymbols[dayOfWeek - 1]
            
            let dayEvents = events.filter { event in
                calendar.isDate(event.timestamp, inSameDayAs: date)
            }
            
            let averageQuality = dayEvents.isEmpty ? 0.0 : 
                dayEvents.map { $0.quality.numericValue }.reduce(0, +) / Double(dayEvents.count)
            
            return WeeklyData(
                dayOfWeek: dayOfWeek,
                dayName: dayName,
                count: dayEvents.count,
                averageQuality: averageQuality
            )
        }.reversed()
    }
}

// Data structure for weekly data
struct WeeklyData {
    let dayOfWeek: Int
    let dayName: String
    let count: Int
    let averageQuality: Double
    
    var qualityColor: Color {
        if averageQuality >= 4.0 {
            return .green
        } else if averageQuality >= 3.0 {
            return .yellow
        } else if averageQuality >= 2.0 {
            return .orange
        } else {
            return .red
        }
    }
    
    var averageQualityText: String {
        if count == 0 {
            return "No data"
        } else if averageQuality >= 4.0 {
            return "Excellent"
        } else if averageQuality >= 3.0 {
            return "Good"
        } else if averageQuality >= 2.0 {
            return "Fair"
        } else {
            return "Poor"
        }
    }
} 