//
//  StatisticsViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 08/06/25.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
final class StatisticsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var totalEvents: Int = 0
    @Published var thisWeekEvents: Int = 0
    @Published var averageDaily: Double = 0.0
    @Published var healthScore: Double = 0.0
    @Published var selectedPeriod: TimePeriod = .quarter {
        didSet {
            generateQualityTrends()
        }
    }
    
    @Published var qualityTrendData: [QualityTrendPoint] = []
    @Published var hourlyData: [HourlyData] = []
    @Published var qualityDistribution: [QualityDistribution] = []
    @Published var weeklyData: [WeeklyData] = []
    @Published var healthInsights: [HealthInsight] = []
    
    private var allEvents: [PeeEvent] = []
    
    var healthScoreInterpretation: String {
        if healthScore > 0.8 {
            return "Excellent"
        } else if healthScore >= 0.6 {
            return "Good"
        } else if healthScore >= 0.4 {
            return "Moderate"
        } else {
            return "Poor"
        }
    }
    
    func loadStatistics(context: ModelContext) {
        loadAllEvents(context: context)
        calculateBasicStatistics()
        generateQualityTrends()
        generateHourlyPatterns()
        generateQualityDistribution()
        generateWeeklyData()
        generateHealthInsights()
    }
    
    // MARK: - Private Methods
    private func loadAllEvents(context: ModelContext) {
        let descriptor = FetchDescriptor<PeeEvent>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        do {
            allEvents = try context.fetch(descriptor)
        } catch {
            print("Failed to fetch events: \(error)")
            allEvents = []
        }
    }
    
    private func calculateBasicStatistics() {
        totalEvents = allEvents.count
        
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        
        thisWeekEvents = allEvents.filter { $0.timestamp >= weekAgo }.count
        
        if !allEvents.isEmpty {
            // Group events by day to count only days with actual events
            let eventsByDay = Dictionary(grouping: allEvents) { event in
                calendar.startOfDay(for: event.timestamp)
            }
            
            // Calculate average based only on days that have events (exclude zero-event days)
            let daysWithEvents = eventsByDay.count
            averageDaily = daysWithEvents > 0 ? Double(totalEvents) / Double(daysWithEvents) : 0.0
            
            // Calculate health score based on quality distribution
            let goodQualities: Set<PeeQuality> = [.clear, .paleYellow, .yellow]
            let goodEvents = allEvents.filter { goodQualities.contains($0.quality) }
            healthScore = totalEvents > 0 ? Double(goodEvents.count) / Double(totalEvents) : 0.0
        }
    }
    
    private func generateQualityTrends() {
        let calendar = Calendar.current
        let now = Date()
        let startDate: Date
        
        switch selectedPeriod {
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
        
        let filteredEvents = allEvents.filter { $0.timestamp >= startDate }
        let groupedByDay = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        
        qualityTrendData = groupedByDay.map { date, events in
            let averageQuality = events.map { $0.quality.numericValue }.reduce(0, +) / Double(events.count)
            return QualityTrendPoint(date: date, averageQuality: averageQuality)
        }.sorted { $0.date < $1.date }
    }
    
    private func generateHourlyPatterns() {
        let groupedByHour = Dictionary(grouping: allEvents) { event in
            Calendar.current.component(.hour, from: event.timestamp)
        }
        
        hourlyData = (0...23).map { hour in
            HourlyData(hour: hour, count: groupedByHour[hour]?.count ?? 0)
        }
    }
    
    private func generateQualityDistribution() {
        let groupedByQuality = Dictionary(grouping: allEvents) { $0.quality }
        
        qualityDistribution = PeeQuality.allCases.compactMap { quality in
            let count = groupedByQuality[quality]?.count ?? 0
            return count > 0 ? QualityDistribution(quality: quality, count: count) : nil
        }.sorted { $0.count > $1.count }
    }
    
    private func generateWeeklyData() {
        let calendar = Calendar.current
        let today = Date()
        
        weeklyData = (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let dayOfWeek = calendar.component(.weekday, from: date)
            let dayName = calendar.shortWeekdaySymbols[dayOfWeek - 1]
            
            let dayEvents = allEvents.filter { event in
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
    
    private func generateHealthInsights() {
        var insights: [HealthInsight] = []
        
        // Hydration insight - now covers all ranges
        if healthScore > 0.8 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Excellent Hydration",
                message: "Your urine quality indicates optimal hydration levels.",
                recommendation: "Keep it up!"
            ))
        } else if healthScore >= 0.6 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Good Hydration",
                message: "You're maintaining healthy hydration levels most of the time.",
                recommendation: "Stay consistent"
            ))
        } else if healthScore >= 0.4 {
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
        if averageDaily > 8 {
            insights.append(HealthInsight(
                type: .info,
                title: "High Frequency",
                message: "You're logging more than 8 events per day on average.",
                recommendation: "Monitor patterns"
            ))
        } else if averageDaily >= 6 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Optimal Frequency",
                message: "Your daily frequency is in the healthy range of 6-8 times.",
                recommendation: "Perfect balance!"
            ))
        } else if averageDaily >= 4 {
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
        let weekEvents = allEvents.filter { event in
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return event.timestamp >= weekAgo
        }
        
        if weekEvents.count > thisWeekEvents {
            insights.append(HealthInsight(
                type: .positive,
                title: "Improving Trend",
                message: "Your tracking consistency has improved this week.",
                recommendation: "Keep tracking!"
            ))
        } else if thisWeekEvents >= 7 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Consistent Tracking",
                message: "You're tracking regularly this week.",
                recommendation: "Great habit!"
            ))
        }
        
        // Quality consistency insight
        let recentQualityVariance = calculateQualityVariance()
        if recentQualityVariance < 0.5 {
            insights.append(HealthInsight(
                type: .positive,
                title: "Stable Quality",
                message: "Your hydration quality is consistent over time.",
                recommendation: "Maintain routine"
            ))
        } else if recentQualityVariance > 1.5 {
            insights.append(HealthInsight(
                type: .info,
                title: "Variable Quality",
                message: "Your hydration quality varies throughout the day.",
                recommendation: "Stay consistent"
            ))
        }
        
        healthInsights = insights
    }
    
    private func calculateQualityVariance() -> Double {
        guard !allEvents.isEmpty else { return 0.0 }
        
        let recentEvents = allEvents.prefix(20) // Last 20 events
        let qualities = recentEvents.map { $0.quality.numericValue }
        let average = qualities.reduce(0, +) / Double(qualities.count)
        let variance = qualities.map { pow($0 - average, 2) }.reduce(0, +) / Double(qualities.count)
        
        return variance
    }
}

// MARK: - Data Structures
enum TimePeriod: String, CaseIterable {
    case week = "Last 7 Days"
    case month = "Last 30 Days"
    case quarter = "Last 90 Days"
}

struct QualityTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let averageQuality: Double
}

struct HourlyData: Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
}

struct QualityDistribution: Identifiable {
    let id = UUID()
    let quality: PeeQuality
    let count: Int
}

struct WeeklyData {
    let dayOfWeek: Int
    let dayName: String
    let count: Int
    let averageQuality: Double
    
    var qualityColor: Color {
        if averageQuality >= 4.0 { return .green }
        if averageQuality >= 3.0 { return .yellow }
        if averageQuality >= 2.0 { return .orange }
        return .red
    }
    
    var averageQualityText: String {
        if count == 0 { return "-" }
        return String(format: "%.1f", averageQuality)
    }
}

enum HealthInsightType {
    case positive, warning, info
    
    var color: Color {
        switch self {
        case .positive: return .green
        case .warning: return .red
        case .info: return .blue
        }
    }
}

struct HealthInsight {
    let type: HealthInsightType
    let title: String
    let message: String
    let recommendation: String?
}

// MARK: - PeeQuality Extension
extension PeeQuality {
    var numericValue: Double {
        switch self {
        case .clear: return 5.0
        case .paleYellow: return 4.0
        case .yellow: return 3.0
        case .darkYellow: return 2.0
        case .amber: return 1.0
        }
    }
} 
