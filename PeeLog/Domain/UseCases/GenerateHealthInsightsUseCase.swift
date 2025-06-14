//
//  GenerateHealthInsightsUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation
import SwiftUI

// Use case for generating health insights
class GenerateHealthInsightsUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(statistics: BasicStatistics, events: [PeeEvent]) -> [HealthInsight] {
        var insights: [HealthInsight] = []
        
        // Hydration insight - now covers all ranges
        if statistics.healthScore > 0.8 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Excellent Hydration",
                message: "Your urine quality indicates optimal hydration levels.",
                recommendation: "Keep it up!"
            ))
        } else if statistics.healthScore >= 0.6 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Good Hydration",
                message: "You're maintaining healthy hydration levels most of the time.",
                recommendation: "Stay consistent"
            ))
        } else if statistics.healthScore >= 0.4 {
            insights.append(HealthInsight(
                type: .info,
                title: "Moderate Hydration",
                message: "Your hydration levels are okay but could be improved.",
                recommendation: "Drink more water"
            ))
        } else {
            insights.append(HealthInsight(
                type: .warning,
                title: "Poor Hydration",
                message: "Your urine suggests you may be dehydrated frequently.",
                recommendation: "Increase water intake"
            ))
        }
        
        // Frequency insight - now covers all ranges
        if statistics.averageDaily > 8 {
            insights.append(HealthInsight(
                type: .info,
                title: "High Frequency",
                message: "You're logging more than 8 events per day on average.",
                recommendation: "Monitor patterns"
            ))
        } else if statistics.averageDaily >= 6 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Optimal Frequency",
                message: "Your daily frequency is in the healthy range of 6-8 times.",
                recommendation: "Perfect balance!"
            ))
        } else if statistics.averageDaily >= 4 {
            insights.append(HealthInsight(
                type: .info,
                title: "Normal Frequency",
                message: "Your frequency is within normal range but could be higher.",
                recommendation: "Consider drinking more"
            ))
        } else {
            insights.append(HealthInsight(
                type: .warning,
                title: "Low Frequency",
                message: "You're logging fewer than 4 events per day.",
                recommendation: "Stay hydrated"
            ))
        }
        
        // Weekly consistency insight
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekEvents = events.filter { event in
            return event.timestamp >= weekAgo
        }
        
        if weekEvents.count > statistics.thisWeekEvents {
            insights.append(HealthInsight(
                type: .positive,
                title: "Improving Trend",
                message: "Your tracking consistency has improved this week.",
                recommendation: "Keep tracking!"
            ))
        } else if statistics.thisWeekEvents >= 7 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Consistent Tracking",
                message: "You're maintaining good tracking habits this week.",
                recommendation: "Great consistency!"
            ))
        }
        
        return insights
    }
}

// Health insight types
enum HealthInsightType {
    case positive
    case info
    case warning
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }
}

// Health insight data structure
struct HealthInsight {
    let type: HealthInsightType
    let title: String
    let message: String
    let recommendation: String?
    
    init(type: HealthInsightType, title: String, message: String, recommendation: String? = nil) {
        self.type = type
        self.title = title
        self.message = message
        self.recommendation = recommendation
    }
} 