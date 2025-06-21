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
    // MARK: - Use Cases
    private let getAllEventsUseCase: GetAllPeeEventsUseCase
    private let calculateStatisticsUseCase: CalculateBasicStatisticsUseCase
    private let generateQualityTrendsUseCase: GenerateQualityTrendsUseCase
    private let generateHealthInsightsUseCase: GenerateHealthInsightsUseCase
    private let analyzeHourlyPatternsUseCase: AnalyzeHourlyPatternsUseCase
    private let generateQualityDistributionUseCase: GenerateQualityDistributionUseCase
    private let generateWeeklyDataUseCase: GenerateWeeklyDataUseCase
    
    // MARK: - Published Properties
    @Published var totalEvents: Int = 0
    @Published var thisWeekEvents: Int = 0
    @Published var averageDaily: Double = 0.0
    @Published var healthScore: Double = 0.0
    // Separate periods for each section
    @Published var qualityTrendsPeriod: TimePeriod = .quarter {
        didSet {
            generateQualityTrends()
        }
    }
    
    @Published var dailyPatternsPeriod: TimePeriod = .quarter {
        didSet {
            generateHourlyPatterns()
        }
    }
    
    @Published var qualityDistributionPeriod: TimePeriod = .allTime {
        didSet {
            generateQualityDistribution()
        }
    }
    
    // Custom date range properties for each section
    @Published var qualityTrendsCustomStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var qualityTrendsCustomEndDate: Date = Date()
    @Published var showingQualityTrendsCustomDatePicker: Bool = false
    
    @Published var dailyPatternsCustomStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var dailyPatternsCustomEndDate: Date = Date()
    @Published var showingDailyPatternsCustomDatePicker: Bool = false
    
    @Published var qualityDistributionCustomStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var qualityDistributionCustomEndDate: Date = Date()
    @Published var showingQualityDistributionCustomDatePicker: Bool = false
    
    @Published var qualityTrendData: [QualityTrendPoint] = []
    @Published var hourlyData: [HourlyData] = []
    @Published var qualityDistribution: [QualityDistribution] = []
    @Published var weeklyData: [WeeklyData] = []
    @Published var healthInsights: [HealthInsight] = []
    
    private var allEvents: [PeeEvent] = []
    private var basicStatistics: BasicStatistics?
    
    // MARK: - Initializer
    init(
        getAllEventsUseCase: GetAllPeeEventsUseCase,
        calculateStatisticsUseCase: CalculateBasicStatisticsUseCase,
        generateQualityTrendsUseCase: GenerateQualityTrendsUseCase,
        generateHealthInsightsUseCase: GenerateHealthInsightsUseCase,
        analyzeHourlyPatternsUseCase: AnalyzeHourlyPatternsUseCase,
        generateQualityDistributionUseCase: GenerateQualityDistributionUseCase,
        generateWeeklyDataUseCase: GenerateWeeklyDataUseCase
    ) {
        self.getAllEventsUseCase = getAllEventsUseCase
        self.calculateStatisticsUseCase = calculateStatisticsUseCase
        self.generateQualityTrendsUseCase = generateQualityTrendsUseCase
        self.generateHealthInsightsUseCase = generateHealthInsightsUseCase
        self.analyzeHourlyPatternsUseCase = analyzeHourlyPatternsUseCase
        self.generateQualityDistributionUseCase = generateQualityDistributionUseCase
        self.generateWeeklyDataUseCase = generateWeeklyDataUseCase
    }
    
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
    
    func loadStatistics() {
        loadAllEvents()
        calculateBasicStatistics()
        generateQualityTrends()
        generateHourlyPatterns()
        generateQualityDistribution()
        generateWeeklyData()
        generateHealthInsights()
    }
    
    // MARK: - Private Methods
    private func loadAllEvents() {
        allEvents = getAllEventsUseCase.execute()
    }
    
    private func calculateBasicStatistics() {
        basicStatistics = calculateStatisticsUseCase.execute(events: allEvents)
        
        // Update published properties
        totalEvents = basicStatistics?.totalEvents ?? 0
        thisWeekEvents = basicStatistics?.thisWeekEvents ?? 0
        averageDaily = basicStatistics?.averageDaily ?? 0.0
        healthScore = basicStatistics?.healthScore ?? 0.0
    }
    
    private func generateQualityTrends() {
        qualityTrendData = generateQualityTrendsUseCase.execute(
            events: allEvents,
            period: qualityTrendsPeriod,
            customStartDate: qualityTrendsCustomStartDate,
            customEndDate: qualityTrendsCustomEndDate
        )
    }
    
    private func generateHourlyPatterns() {
        hourlyData = analyzeHourlyPatternsUseCase.execute(
            events: allEvents,
            period: dailyPatternsPeriod,
            customStartDate: dailyPatternsCustomStartDate,
            customEndDate: dailyPatternsCustomEndDate
        )
    }
    
    private func generateQualityDistribution() {
        qualityDistribution = generateQualityDistributionUseCase.execute(
            events: allEvents,
            period: qualityDistributionPeriod,
            customStartDate: qualityDistributionCustomStartDate,
            customEndDate: qualityDistributionCustomEndDate
        )
    }
    
    private func generateWeeklyData() {
        weeklyData = generateWeeklyDataUseCase.execute(events: allEvents)
    }
    
    private func generateHealthInsights() {
        guard let stats = basicStatistics else { return }
        healthInsights = generateHealthInsightsUseCase.execute(statistics: stats, events: allEvents)
    }
    
    func updateQualityTrendsCustomDateRange(startDate: Date, endDate: Date) {
        qualityTrendsCustomStartDate = startDate
        qualityTrendsCustomEndDate = endDate
        if qualityTrendsPeriod == .custom {
            generateQualityTrends()
        }
    }
    
    func updateDailyPatternsCustomDateRange(startDate: Date, endDate: Date) {
        dailyPatternsCustomStartDate = startDate
        dailyPatternsCustomEndDate = endDate
        if dailyPatternsPeriod == .custom {
            generateHourlyPatterns()
        }
    }
    
    func updateQualityDistributionCustomDateRange(startDate: Date, endDate: Date) {
        qualityDistributionCustomStartDate = startDate
        qualityDistributionCustomEndDate = endDate
        if qualityDistributionPeriod == .custom {
            generateQualityDistribution()
        }
    }
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
 