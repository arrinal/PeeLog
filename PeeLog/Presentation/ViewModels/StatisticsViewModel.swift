//
//  StatisticsViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 08/06/25.
//

import Foundation
import SwiftData
import SwiftUI
import Combine

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
    var useRemoteRefreshAllowed: Bool { useRemote }
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published var totalEvents: Int = 0
    @Published var thisWeekEvents: Int = 0
    @Published var averageDaily: Double = 0.0
    @Published var healthScore: Double = 0.0
    // Separate periods for each section
    @Published var qualityTrendsPeriod: TimePeriod = .quarter {
        didSet { /* debounced in setupDebounce() */ }
    }
    
    @Published var dailyPatternsPeriod: TimePeriod = .quarter {
        didSet { /* debounced in setupDebounce() */ }
    }
    
    @Published var qualityDistributionPeriod: TimePeriod = .allTime {
        didSet { /* debounced in setupDebounce() */ }
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
    // Loading flags per section
    @Published var isLoadingOverview: Bool = false
    @Published var isLoadingTrends: Bool = false
    @Published var isLoadingHourly: Bool = false
    @Published var isLoadingDistribution: Bool = false
    @Published var isLoadingWeekly: Bool = false
    @Published var isLoadingInsights: Bool = false
    // Data source badges per section (future use)
    @Published var overviewSource: AnalyticsDataSource = .remote
    @Published var trendsSource: AnalyticsDataSource = .remote
    @Published var hourlySource: AnalyticsDataSource = .remote
    @Published var distributionSource: AnalyticsDataSource = .remote
    @Published var weeklySource: AnalyticsDataSource = .remote
    @Published var insightsSource: AnalyticsDataSource = .remote
    
    private var allEvents: [PeeEvent] = []
    private var basicStatistics: BasicStatistics?
    private var lastAnalyticsRefreshAt: Date?
    private let foregroundRefreshThresholdSeconds: TimeInterval = 60 * 30
    
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
        setupDebounce()
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
            Task { await loadOfflineFromCacheThenLocal() }
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
        // set loading flags
        isLoadingOverview = true
        isLoadingTrends = true
        isLoadingHourly = true
        isLoadingDistribution = true
        isLoadingWeekly = true
        isLoadingInsights = true

        let overviewRange = loadPeriodRange(.allTime, customStart: Date.distantPast, customEnd: Date())
        let trendsRange = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        let hourlyRange = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
        let distRange = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)

        // Prepare local data in case we need graceful fallback
        let fallbackEvents = getAllEventsUseCase.execute()
        self.allEvents = fallbackEvents

        // Parallel fetches using async-let with Sourced<T> results
        async let ovTask = analyticsRepository.fetchOverview(range: overviewRange)
        async let trTask = analyticsRepository.fetchQualityTrends(range: trendsRange)
        async let hoTask = analyticsRepository.fetchHourly(range: hourlyRange)
        async let diTask = analyticsRepository.fetchQualityDistribution(range: distRange)
        async let weTask = analyticsRepository.fetchWeekly()
        async let insTask = analyticsRepository.fetchInsights(range: trendsRange)

        do {
            let ov = try await ovTask
            totalEvents = ov.data.stats.totalEvents
            thisWeekEvents = ov.data.stats.thisWeekEvents
            averageDaily = ov.data.stats.averageDaily
            healthScore = ov.data.stats.healthScore
            healthScoreInterpretationServer = ov.data.interpretationLabel
            overviewSource = ov.source
            debugPrint("[Analytics] Overview source=\(overviewSource.rawValue)")
        } catch {
            // Fallback to local computations if overview fails completely
            loadLocal()
            overviewSource = .local
            NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Overview from local"])
            debugPrint("[Analytics] Overview source=local (fallback)")
        }
        isLoadingOverview = false

        if let tr = try? await trTask {
            qualityTrendData = tr.data
            trendsSource = tr.source
            if tr.source == .cache {
                NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Trends from cache"])
            }
            debugPrint("[Analytics] Trends source=\(trendsSource.rawValue) period=\(qualityTrendsPeriod.rawValue)")
        } else {
            // Local fallback
            generateQualityTrends()
            trendsSource = .local
            NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Trends from local"])
            debugPrint("[Analytics] Trends source=local (fallback) period=\(qualityTrendsPeriod.rawValue)")
        }
        isLoadingTrends = false

        if let ho = try? await hoTask {
            hourlyData = ho.data
            hourlySource = ho.source
            if ho.source == .cache {
                NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Hourly from cache"])
            }
            debugPrint("[Analytics] Hourly source=\(hourlySource.rawValue) period=\(dailyPatternsPeriod.rawValue)")
        } else {
            generateHourlyPatterns()
            hourlySource = .local
            NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Hourly from local"])
            debugPrint("[Analytics] Hourly source=local (fallback) period=\(dailyPatternsPeriod.rawValue)")
        }
        isLoadingHourly = false

        if let di = try? await diTask {
            qualityDistribution = di.data
            distributionSource = di.source
            if di.source == .cache {
                NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Distribution from cache"])
            }
            debugPrint("[Analytics] Distribution source=\(distributionSource.rawValue) period=\(qualityDistributionPeriod.rawValue)")
        } else {
            generateQualityDistribution()
            distributionSource = .local
            NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Distribution from local"])
            debugPrint("[Analytics] Distribution source=local (fallback) period=\(qualityDistributionPeriod.rawValue)")
        }
        isLoadingDistribution = false

        if let we = try? await weTask {
            weeklyData = we.data
            weeklySource = we.source
            if we.source == .cache {
                NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Weekly from cache"])
            }
            debugPrint("[Analytics] Weekly source=\(weeklySource.rawValue)")
        } else {
            generateWeeklyData()
            weeklySource = .local
            NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Weekly from local"])
            debugPrint("[Analytics] Weekly source=local (fallback)")
        }
        isLoadingWeekly = false

        if let ins = try? await insTask {
            healthInsights = ins.data
            insightsSource = ins.source
            if ins.source == .cache {
                NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Insights from cache"])
            }
            debugPrint("[Analytics] Insights source=\(insightsSource.rawValue) period=\(qualityTrendsPeriod.rawValue)")
        } else {
            // Local insights require basic statistics; compute without touching published overview values
            let stats = calculateStatisticsUseCase.execute(events: allEvents)
            healthInsights = generateHealthInsightsUseCase.execute(statistics: stats, events: allEvents)
            insightsSource = .local
            NotificationCenter.default.post(name: .serverStatusToast, object: nil, userInfo: ["message": "Server unavailable — Insights from local"])
            debugPrint("[Analytics] Insights source=local (fallback) period=\(qualityTrendsPeriod.rawValue)")
        }
        isLoadingInsights = false

        // Prewarm cache for common ranges (fire-and-forget)
        Task { await prewarmAnalyticsCache() }
        lastAnalyticsRefreshAt = Date()
    }

    // MARK: - Foreground refresh
    func refreshOnForegroundIfStale() {
        guard useRemote && networkMonitor.isOnline else { return }
        if let last = lastAnalyticsRefreshAt, Date().timeIntervalSince(last) < foregroundRefreshThresholdSeconds {
            return
        }
        Task { await silentRefresh() }
    }

    private func silentRefresh() async {
        let overviewRange = loadPeriodRange(.allTime, customStart: Date.distantPast, customEnd: Date())
        let trendsRange = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        let hourlyRange = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
        let distRange = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)

        async let ovTask = analyticsRepository.fetchOverview(range: overviewRange)
        async let trTask = analyticsRepository.fetchQualityTrends(range: trendsRange)
        async let hoTask = analyticsRepository.fetchHourly(range: hourlyRange)
        async let diTask = analyticsRepository.fetchQualityDistribution(range: distRange)
        async let weTask = analyticsRepository.fetchWeekly()
        async let insTask = analyticsRepository.fetchInsights(range: trendsRange)

        var anyRemoteSuccess = false

        if let ov = try? await ovTask {
            totalEvents = ov.data.stats.totalEvents
            thisWeekEvents = ov.data.stats.thisWeekEvents
            averageDaily = ov.data.stats.averageDaily
            healthScore = ov.data.stats.healthScore
            healthScoreInterpretationServer = ov.data.interpretationLabel
            if ov.source == .remote { overviewSource = .remote; anyRemoteSuccess = true }
        }
        if let tr = try? await trTask {
            qualityTrendData = tr.data
            if tr.source == .remote { trendsSource = .remote; anyRemoteSuccess = true }
        }
        if let ho = try? await hoTask {
            hourlyData = ho.data
            if ho.source == .remote { hourlySource = .remote; anyRemoteSuccess = true }
        }
        if let di = try? await diTask {
            qualityDistribution = di.data
            if di.source == .remote { distributionSource = .remote; anyRemoteSuccess = true }
        }
        if let we = try? await weTask {
            weeklyData = we.data
            if we.source == .remote { weeklySource = .remote; anyRemoteSuccess = true }
        }
        if let ins = try? await insTask {
            healthInsights = ins.data
            if ins.source == .remote { insightsSource = .remote; anyRemoteSuccess = true }
        }

        if anyRemoteSuccess {
            lastAnalyticsRefreshAt = Date()
        }
    }

    private func prewarmAnalyticsCache() async {
        guard useRemote && networkMonitor.isOnline else { return }
        let monthRange = loadPeriodRange(.month, customStart: Date(), customEnd: Date())
        let weekRange = loadPeriodRange(.week, customStart: Date(), customEnd: Date())
        let distRange = loadPeriodRange(.month, customStart: Date(), customEnd: Date())
        // Sequential prewarm to avoid Sendable actor issues
        _ = try? await analyticsRepository.fetchQualityTrends(range: monthRange)
        _ = try? await analyticsRepository.fetchHourly(range: weekRange)
        _ = try? await analyticsRepository.fetchQualityDistribution(range: distRange)
    }

    // MARK: - Offline immediate refresh (cache → local)
    func refreshOfflineImmediate() async {
        await loadOfflineFromCacheThenLocal()
    }

    private func loadOfflineFromCacheThenLocal() async {
        // Ensure no shimmers while offline
        isLoadingOverview = false
        isLoadingTrends = false
        isLoadingHourly = false
        isLoadingDistribution = false
        isLoadingWeekly = false
        isLoadingInsights = false

        // Prepare local data for fallback
        loadAllEvents()
        calculateBasicStatistics()

        let overviewRange = loadPeriodRange(.allTime, customStart: Date.distantPast, customEnd: Date())
        let trendsRange = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        let hourlyRange = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
        let distRange = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)

        // Overview: prefer cached, else keep local stats already set above
        if let ov = try? await analyticsRepository.fetchOverview(range: overviewRange) {
            totalEvents = ov.data.stats.totalEvents
            thisWeekEvents = ov.data.stats.thisWeekEvents
            averageDaily = ov.data.stats.averageDaily
            healthScore = ov.data.stats.healthScore
            healthScoreInterpretationServer = ov.data.interpretationLabel
            overviewSource = ov.source
            debugPrint("[Analytics] Offline Overview source=\(overviewSource.rawValue)")
        } else {
            overviewSource = .local
            debugPrint("[Analytics] Offline Overview source=local (fallback)")
        }

        // Trends
        if let tr = try? await analyticsRepository.fetchQualityTrends(range: trendsRange) {
            qualityTrendData = tr.data
            trendsSource = tr.source
            debugPrint("[Analytics] Offline Trends source=\(trendsSource.rawValue)")
        } else {
            generateQualityTrends()
            trendsSource = .local
            debugPrint("[Analytics] Offline Trends source=local (fallback)")
        }

        // Hourly
        if let ho = try? await analyticsRepository.fetchHourly(range: hourlyRange) {
            hourlyData = ho.data
            hourlySource = ho.source
            debugPrint("[Analytics] Offline Hourly source=\(hourlySource.rawValue)")
        } else {
            generateHourlyPatterns()
            hourlySource = .local
            debugPrint("[Analytics] Offline Hourly source=local (fallback)")
        }

        // Distribution
        if let di = try? await analyticsRepository.fetchQualityDistribution(range: distRange) {
            qualityDistribution = di.data
            distributionSource = di.source
            debugPrint("[Analytics] Offline Distribution source=\(distributionSource.rawValue)")
        } else {
            generateQualityDistribution()
            distributionSource = .local
            debugPrint("[Analytics] Offline Distribution source=local (fallback)")
        }

        // Weekly
        if let we = try? await analyticsRepository.fetchWeekly() {
            weeklyData = we.data
            weeklySource = we.source
            debugPrint("[Analytics] Offline Weekly source=\(weeklySource.rawValue)")
        } else {
            generateWeeklyData()
            weeklySource = .local
            debugPrint("[Analytics] Offline Weekly source=local (fallback)")
        }

        // Insights
        if let ins = try? await analyticsRepository.fetchInsights(range: trendsRange) {
            healthInsights = ins.data
            insightsSource = ins.source
            debugPrint("[Analytics] Offline Insights source=\(insightsSource.rawValue)")
        } else {
            // Use already computed basicStatistics
            healthInsights = generateHealthInsightsUseCase.execute(statistics: basicStatistics!, events: allEvents)
            insightsSource = .local
            debugPrint("[Analytics] Offline Insights source=local (fallback)")
        }
    }

    private func setupDebounce() {
        $qualityTrendsPeriod
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.useRemote && self.networkMonitor.isOnline {
                    Task { await self.fetchRemoteQualityTrends() }
                } else {
                    self.generateQualityTrends()
                }
            }
            .store(in: &cancellables)

        $dailyPatternsPeriod
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.useRemote && self.networkMonitor.isOnline {
                    Task { await self.fetchRemoteHourly() }
                } else {
                    self.generateHourlyPatterns()
                }
            }
            .store(in: &cancellables)

        $qualityDistributionPeriod
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                if self.useRemote && self.networkMonitor.isOnline {
                    Task { await self.fetchRemoteDistribution() }
                } else {
                    self.generateQualityDistribution()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Remote fetch helpers
    private func fetchRemoteQualityTrends() async {
        isLoadingTrends = true
        let range = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        if let result = try? await analyticsRepository.fetchQualityTrends(range: range) {
            self.qualityTrendData = result.data
            self.trendsSource = result.source
        }
        isLoadingTrends = false
    }
    
    private func fetchRemoteHourly() async {
        isLoadingHourly = true
        let range = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
        if let result = try? await analyticsRepository.fetchHourly(range: range) {
            self.hourlyData = result.data
            self.hourlySource = result.source
        }
        isLoadingHourly = false
    }
    
    private func fetchRemoteDistribution() async {
        isLoadingDistribution = true
        let range = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)
        if let result = try? await analyticsRepository.fetchQualityDistribution(range: range) {
            self.qualityDistribution = result.data
            self.distributionSource = result.source
        }
        isLoadingDistribution = false
    }
    
    private func fetchRemoteWeekly() async {
        isLoadingWeekly = true
        if let result = try? await analyticsRepository.fetchWeekly() {
            self.weeklyData = result.data
            self.weeklySource = result.source
        }
        isLoadingWeekly = false
    }
    
    private func fetchRemoteInsights() async {
        isLoadingInsights = true
        let range = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        if let result = try? await analyticsRepository.fetchInsights(range: range) {
            self.healthInsights = result.data
            self.insightsSource = result.source
        }
        isLoadingInsights = false
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
 