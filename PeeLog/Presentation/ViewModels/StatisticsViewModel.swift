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
    private let analyticsRepository: AnalyticsRepository
    private let useRemote: Bool = true // feature flag: prefer backend when available
    private let networkMonitor = NetworkMonitor.shared
    
    // MARK: - Published Properties
    @Published var totalEvents: Int = 0
    @Published var thisWeekEvents: Int = 0
    @Published var averageDaily: Double = 0.0
    @Published var healthScore: Double = 0.0
    // Separate periods for each section
    @Published var qualityTrendsPeriod: TimePeriod = .quarter {
        didSet {
            if useRemote {
                Task { await fetchRemoteQualityTrends() }
            } else {
                generateQualityTrends()
            }
        }
    }
    
    @Published var dailyPatternsPeriod: TimePeriod = .quarter {
        didSet {
            if useRemote {
                Task { await fetchRemoteHourly() }
            } else {
                generateHourlyPatterns()
            }
        }
    }
    
    @Published var qualityDistributionPeriod: TimePeriod = .allTime {
        didSet {
            if useRemote {
                Task { await fetchRemoteDistribution() }
            } else {
                generateQualityDistribution()
            }
        }
    }
    
    // Custom date range properties for each section
    @Published var qualityTrendsCustomStartDate: Date = CalendarUtility.daysAgo(7)
    @Published var qualityTrendsCustomEndDate: Date = Date()
    @Published var showingQualityTrendsCustomDatePicker: Bool = false
    
    @Published var dailyPatternsCustomStartDate: Date = CalendarUtility.daysAgo(7)
    @Published var dailyPatternsCustomEndDate: Date = Date()
    @Published var showingDailyPatternsCustomDatePicker: Bool = false
    
    @Published var qualityDistributionCustomStartDate: Date = CalendarUtility.daysAgo(7)
    @Published var qualityDistributionCustomEndDate: Date = Date()
    @Published var showingQualityDistributionCustomDatePicker: Bool = false
    
    @Published var qualityTrendData: [QualityTrendPoint] = []
    @Published var hourlyData: [HourlyData] = []
    @Published var qualityDistribution: [QualityDistribution] = []
    @Published var weeklyData: [WeeklyData] = []
    @Published var healthInsights: [HealthInsight] = []
    @Published private var healthScoreInterpretationServer: String?
    
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
        generateWeeklyDataUseCase: GenerateWeeklyDataUseCase,
        analyticsRepository: AnalyticsRepository
    ) {
        self.getAllEventsUseCase = getAllEventsUseCase
        self.calculateStatisticsUseCase = calculateStatisticsUseCase
        self.generateQualityTrendsUseCase = generateQualityTrendsUseCase
        self.generateHealthInsightsUseCase = generateHealthInsightsUseCase
        self.analyzeHourlyPatternsUseCase = analyzeHourlyPatternsUseCase
        self.generateQualityDistributionUseCase = generateQualityDistributionUseCase
        self.generateWeeklyDataUseCase = generateWeeklyDataUseCase
        self.analyticsRepository = analyticsRepository
    }
    
    var healthScoreInterpretation: String {
        if let server = healthScoreInterpretationServer, !server.isEmpty { return server }
        if healthScore > 0.85 { return "Excellent" }
        else if healthScore >= 0.7 { return "Good" }
        else if healthScore >= 0.5 { return "Moderate" }
        else if healthScore >= 0.3 { return "Poor" }
        else { return "Very Poor" }
    }
    
    func loadStatistics() {
        if useRemote && networkMonitor.isOnline {
            Task { await loadRemote() }
        } else {
            loadLocal()
        }
    }

    private func loadLocal() {
        loadAllEvents()
        calculateBasicStatistics()
        generateQualityTrends()
        generateHourlyPatterns()
        generateQualityDistribution()
        generateWeeklyData()
        generateHealthInsights()
    }

    private func analyticsRange(for period: TimePeriod, start: Date, end: Date) -> AnalyticsRange {
        return AnalyticsRange(period: period, startDate: start, endDate: end, timeZone: TimeZone.current)
    }

    private func loadPeriodRange(_ period: TimePeriod, customStart: Date, customEnd: Date) -> AnalyticsRange {
        switch period {
        case .custom:
            return analyticsRange(for: period, start: customStart, end: customEnd)
        case .week:
            let r = TimePeriod.week.dateRange
            return analyticsRange(for: .week, start: r.start, end: r.end)
        case .month:
            let r = TimePeriod.month.dateRange
            return analyticsRange(for: .month, start: r.start, end: r.end)
        case .quarter:
            let r = TimePeriod.quarter.dateRange
            return analyticsRange(for: .quarter, start: r.start, end: r.end)
        case .allTime:
            let r = TimePeriod.allTime.dateRange
            return analyticsRange(for: .allTime, start: r.start, end: r.end)
        default:
            let r = TimePeriod.week.dateRange
            return analyticsRange(for: .week, start: r.start, end: r.end)
        }
    }

    private func loadRemote() async {
        do {
            // Overview
            let overviewRange = loadPeriodRange(.allTime, customStart: Date.distantPast, customEnd: Date())
            let overview = try await analyticsRepository.fetchOverview(range: overviewRange)
            self.totalEvents = overview.stats.totalEvents
            self.thisWeekEvents = overview.stats.thisWeekEvents
            self.averageDaily = overview.stats.averageDaily
            self.healthScore = overview.stats.healthScore
            self.healthScoreInterpretationServer = overview.interpretationLabel

            // Trends
            let trendsRange = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
            self.qualityTrendData = try await analyticsRepository.fetchQualityTrends(range: trendsRange)

            // Hourly
            let hourlyRange = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
            self.hourlyData = try await analyticsRepository.fetchHourly(range: hourlyRange)

            // Distribution
            let distRange = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)
            self.qualityDistribution = try await analyticsRepository.fetchQualityDistribution(range: distRange)

            // Weekly
            self.weeklyData = try await analyticsRepository.fetchWeekly()

            // Insights (use same range as trends by default)
            let insights = try await analyticsRepository.fetchInsights(range: trendsRange)
            self.healthInsights = insights
        } catch {
            // Fallback to local if remote fails
            loadLocal()
        }
    }

    // MARK: - Remote fetch helpers
    private func fetchRemoteQualityTrends() async {
        let range = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        if let result = try? await analyticsRepository.fetchQualityTrends(range: range) {
            self.qualityTrendData = result
        }
    }
    
    private func fetchRemoteHourly() async {
        let range = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
        if let result = try? await analyticsRepository.fetchHourly(range: range) {
            self.hourlyData = result
        }
    }
    
    private func fetchRemoteDistribution() async {
        let range = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)
        if let result = try? await analyticsRepository.fetchQualityDistribution(range: range) {
            self.qualityDistribution = result
        }
    }
    
    private func fetchRemoteWeekly() async {
        if let result = try? await analyticsRepository.fetchWeekly() {
            self.weeklyData = result
        }
    }
    
    private func fetchRemoteInsights() async {
        let range = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        if let result = try? await analyticsRepository.fetchInsights(range: range) {
            self.healthInsights = result
        }
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
            if useRemote && networkMonitor.isOnline {
                Task { await fetchRemoteQualityTrends() }
            } else {
                generateQualityTrends()
            }
        }
    }
    
    func updateDailyPatternsCustomDateRange(startDate: Date, endDate: Date) {
        dailyPatternsCustomStartDate = startDate
        dailyPatternsCustomEndDate = endDate
        if dailyPatternsPeriod == .custom {
            if useRemote && networkMonitor.isOnline {
                Task { await fetchRemoteHourly() }
            } else {
                generateHourlyPatterns()
            }
        }
    }
    
    func updateQualityDistributionCustomDateRange(startDate: Date, endDate: Date) {
        qualityDistributionCustomStartDate = startDate
        qualityDistributionCustomEndDate = endDate
        if qualityDistributionPeriod == .custom {
            if useRemote && networkMonitor.isOnline {
                Task { await fetchRemoteDistribution() }
            } else {
                generateQualityDistribution()
            }
        }
    }
}



// MARK: - PeeQuality Extension
extension PeeQuality {
    var numericValue: Double {
        switch self {
        case .paleYellow: return 5.0  // Optimal hydration
        case .clear: return 3.5       // Overhydrated (concerning)
        case .yellow: return 2.5      // Mildly dehydrated
        case .darkYellow: return 1.5  // Dehydrated
        case .amber: return 1.0       // Severely dehydrated
        }
    }
} 
 