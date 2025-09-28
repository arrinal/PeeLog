//
//  GenerateWeeklyDataUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation
import SwiftUI

// Use case for generating weekly data
@MainActor
class GenerateWeeklyDataUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent]) -> [WeeklyData] {
        // Using CalendarUtility for date operations
        let today = Date()
        
        return (0..<7).map { dayOffset in
            let date = CalendarUtility.date(byAddingDays: -dayOffset, to: today) ?? today
            let dayOfWeek = CalendarUtility.current.component(.weekday, from: date)
            let dayName = CalendarUtility.current.shortWeekdaySymbols[dayOfWeek - 1]
            
            let dayEvents = events.filter { event in
                CalendarUtility.isDate(event.timestamp, inSameDayAs: date)
            }
            
            let averageQuality = dayEvents.isEmpty ? 0.0 :
                dayEvents.map { $0.quality.numericValue }.reduce(0, +) / Double(dayEvents.count)

            // Derive severity for fallback/local mode only (server provides this in remote mode)
            let severity: String
            if dayEvents.count == 0 {
                severity = "none"
            } else if averageQuality >= 4.0 {
                severity = "excellent"
            } else if averageQuality >= 3.0 {
                severity = "good"
            } else if averageQuality >= 2.0 {
                severity = "fair"
            } else {
                severity = "poor"
            }

            return WeeklyData(
                dayOfWeek: dayOfWeek,
                dayName: dayName,
                count: dayEvents.count,
                averageQuality: averageQuality,
                severity: severity
            )
        }.reversed()
    }
}

// Data structure for weekly data
struct WeeklyData: Sendable {
    let dayOfWeek: Int
    let dayName: String
    let count: Int
    let averageQuality: Double
    let severity: String // none|poor|fair|good|excellent

    var qualityColor: Color {
        switch severity {
        case "none": return Color(.systemGray4)
        case "poor": return .red
        case "fair": return .orange
        case "good": return .yellow
        case "excellent": return .green
        default:
            // Fallback to previous threshold-based color if an unknown severity is received
            if count == 0 {
                return Color(.systemGray4)
            } else if averageQuality >= 4.0 {
                return .green
            } else if averageQuality >= 3.0 {
                return .yellow
            } else if averageQuality >= 2.0 {
                return .orange
            } else {
                return .red
            }
        }
    }

    var averageQualityText: String {
        switch severity {
        case "none": return "No data"
        case "poor": return "Poor"
        case "fair": return "Fair"
        case "good": return "Good"
        case "excellent": return "Excellent"
        default:
            if count == 0 { return "No data" }
            else if averageQuality >= 4.0 { return "Excellent" }
            else if averageQuality >= 3.0 { return "Good" }
            else if averageQuality >= 2.0 { return "Fair" }
            else { return "Poor" }
        }
    }
}