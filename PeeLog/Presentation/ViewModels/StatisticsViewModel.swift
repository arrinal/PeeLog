//
//  StatisticsViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 08/06/25.
//

import Foundation
import Combine

@MainActor
final class StatisticsViewModel: ObservableObject {
    // MARK: - Use Cases
    private let analyticsRepository: AnalyticsRepository
    private let networkMonitor = NetworkMonitor.shared
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
    
    @Published var lastSyncedAt: Date?
    
    var isDataStale: Bool {
        // Strategy 1 (backend-only): stale when offline OR when we are showing cached data.
        if !networkMonitor.isOnline { return true }
        return [
            overviewSource,
            trendsSource,
            hourlySource,
            distributionSource,
            weeklySource,
            insightsSource
        ].contains(.cache)
    }
    
    private let foregroundRefreshThresholdSeconds: TimeInterval = 60 * 30
    private var observersInstalled = false
    private var isStoreResetting = false
    
    // MARK: - Initializer
    init(analyticsRepository: AnalyticsRepository) {
        self.analyticsRepository = analyticsRepository
        setupDebounce()
        installStoreResetObserversIfNeeded()
    }

    private func installStoreResetObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(forName: .eventsStoreWillReset, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isStoreResetting = true
                self.totalEvents = 0
                self.thisWeekEvents = 0
                self.averageDaily = 0
                self.healthScore = 0
                self.qualityTrendData = []
                self.hourlyData = []
                self.qualityDistribution = []
                self.weeklyData = []
                self.healthInsights = []
                self.lastSyncedAt = nil
            }
        }
        NotificationCenter.default.addObserver(forName: .eventsStoreDidReset, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isStoreResetting = false
                self.loadStatistics()
            }
        }
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
        // Always prefer remote if online, otherwise check cache
        if networkMonitor.isOnline {
            Task { await loadRemote() }
        } else {
            Task { await loadOfflineFromCache() }
        }
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

        // Parallel fetches using async-let with Sourced<T> results
        async let ovTask = analyticsRepository.fetchOverview(range: overviewRange)
        async let trTask = analyticsRepository.fetchQualityTrends(range: trendsRange)
        async let hoTask = analyticsRepository.fetchHourly(range: hourlyRange)
        async let diTask = analyticsRepository.fetchQualityDistribution(range: distRange)
        async let weTask = analyticsRepository.fetchWeekly()
        async let insTask = analyticsRepository.fetchInsights(range: trendsRange)

        var successCount = 0
        var remoteSuccessCount = 0
        
        do {
            let ov = try await ovTask
            totalEvents = ov.data.stats.totalEvents
            thisWeekEvents = ov.data.stats.thisWeekEvents
            averageDaily = ov.data.stats.averageDaily
            healthScore = ov.data.stats.healthScore
            healthScoreInterpretationServer = ov.data.interpretationLabel
            overviewSource = ov.source
            successCount += 1
            if ov.source == .remote { remoteSuccessCount += 1 }
        } catch {
            overviewSource = .cache // Treat failure as cache/unavailable
        }
        isLoadingOverview = false

        if let tr = try? await trTask {
            qualityTrendData = tr.data
            trendsSource = tr.source
            successCount += 1
            if tr.source == .remote { remoteSuccessCount += 1 }
        } else {
            trendsSource = .cache
        }
        isLoadingTrends = false

        if let ho = try? await hoTask {
            hourlyData = ho.data
            hourlySource = ho.source
            successCount += 1
            if ho.source == .remote { remoteSuccessCount += 1 }
        } else {
            hourlySource = .cache
        }
        isLoadingHourly = false

        if let di = try? await diTask {
            qualityDistribution = di.data
            distributionSource = di.source
            successCount += 1
            if di.source == .remote { remoteSuccessCount += 1 }
        } else {
            distributionSource = .cache
        }
        isLoadingDistribution = false

        if let we = try? await weTask {
            weeklyData = we.data
            weeklySource = we.source
            successCount += 1
            if we.source == .remote { remoteSuccessCount += 1 }
        } else {
            weeklySource = .cache
        }
        isLoadingWeekly = false

        if let ins = try? await insTask {
            healthInsights = ins.data
            insightsSource = ins.source
            successCount += 1
            if ins.source == .remote { remoteSuccessCount += 1 }
        } else {
            insightsSource = .cache
        }
        isLoadingInsights = false

        // Update lastSyncedAt only when at least some responses came from the backend.
        // This ensures offline/cache reads don't incorrectly look "fresh".
        if remoteSuccessCount > 0 {
            lastSyncedAt = Date()
        }
        
        // Prewarm cache for common ranges (fire-and-forget)
        Task { await prewarmAnalyticsCache() }
    }

    // MARK: - Foreground refresh
    func refreshOnForegroundIfStale() {
        guard networkMonitor.isOnline else { return }
        if let last = lastSyncedAt, Date().timeIntervalSince(last) < foregroundRefreshThresholdSeconds {
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
            lastSyncedAt = Date()
        }
    }

    private func prewarmAnalyticsCache() async {
        guard networkMonitor.isOnline else { return }
        let monthRange = loadPeriodRange(.month, customStart: Date(), customEnd: Date())
        let weekRange = loadPeriodRange(.week, customStart: Date(), customEnd: Date())
        let distRange = loadPeriodRange(.month, customStart: Date(), customEnd: Date())
        // Sequential prewarm to avoid Sendable actor issues
        _ = try? await analyticsRepository.fetchQualityTrends(range: monthRange)
        _ = try? await analyticsRepository.fetchHourly(range: weekRange)
        _ = try? await analyticsRepository.fetchQualityDistribution(range: distRange)
    }

    // MARK: - Offline immediate refresh (cache only)
    func refreshOfflineImmediate() async {
        await loadOfflineFromCache()
    }

    private func loadOfflineFromCache() async {
        // Ensure no shimmers while offline
        isLoadingOverview = false
        isLoadingTrends = false
        isLoadingHourly = false
        isLoadingDistribution = false
        isLoadingWeekly = false
        isLoadingInsights = false

        let overviewRange = loadPeriodRange(.allTime, customStart: Date.distantPast, customEnd: Date())
        let trendsRange = loadPeriodRange(qualityTrendsPeriod, customStart: qualityTrendsCustomStartDate, customEnd: qualityTrendsCustomEndDate)
        let hourlyRange = loadPeriodRange(dailyPatternsPeriod, customStart: dailyPatternsCustomStartDate, customEnd: dailyPatternsCustomEndDate)
        let distRange = loadPeriodRange(qualityDistributionPeriod, customStart: qualityDistributionCustomStartDate, customEnd: qualityDistributionCustomEndDate)

        // Overview
        if let ov = try? await analyticsRepository.fetchOverview(range: overviewRange) {
            totalEvents = ov.data.stats.totalEvents
            thisWeekEvents = ov.data.stats.thisWeekEvents
            averageDaily = ov.data.stats.averageDaily
            healthScore = ov.data.stats.healthScore
            healthScoreInterpretationServer = ov.data.interpretationLabel
            overviewSource = ov.source
        } else {
            overviewSource = .cache
        }

        // Trends
        if let tr = try? await analyticsRepository.fetchQualityTrends(range: trendsRange) {
            qualityTrendData = tr.data
            trendsSource = tr.source
        } else {
            trendsSource = .cache
        }

        // Hourly
        if let ho = try? await analyticsRepository.fetchHourly(range: hourlyRange) {
            hourlyData = ho.data
            hourlySource = ho.source
        } else {
            hourlySource = .cache
        }

        // Distribution
        if let di = try? await analyticsRepository.fetchQualityDistribution(range: distRange) {
            qualityDistribution = di.data
            distributionSource = di.source
        } else {
            distributionSource = .cache
        }

        // Weekly
        if let we = try? await analyticsRepository.fetchWeekly() {
            weeklyData = we.data
            weeklySource = we.source
        } else {
            weeklySource = .cache
        }

        // Insights
        if let ins = try? await analyticsRepository.fetchInsights(range: trendsRange) {
            healthInsights = ins.data
            insightsSource = ins.source
        } else {
            insightsSource = .cache
        }
    }

    private func setupDebounce() {
        $qualityTrendsPeriod
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Repo already handles cache fallback; ViewModel never performs local calculations.
                Task { await self.fetchRemoteQualityTrends() }
            }
            .store(in: &cancellables)

        $dailyPatternsPeriod
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Repo already handles cache fallback; ViewModel never performs local calculations.
                Task { await self.fetchRemoteHourly() }
            }
            .store(in: &cancellables)

        $qualityDistributionPeriod
            .removeDuplicates()
            .debounce(for: .milliseconds(350), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                // Repo already handles cache fallback; ViewModel never performs local calculations.
                Task { await self.fetchRemoteDistribution() }
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
    
    func updateQualityTrendsCustomDateRange(startDate: Date, endDate: Date) {
        qualityTrendsCustomStartDate = startDate
        qualityTrendsCustomEndDate = endDate
        if qualityTrendsPeriod == .custom {
            if networkMonitor.isOnline {
                Task { await fetchRemoteQualityTrends() }
            } else {
                Task { await fetchRemoteQualityTrends() } // Repo handles cache fallback
            }
        }
    }
    
    func updateDailyPatternsCustomDateRange(startDate: Date, endDate: Date) {
        dailyPatternsCustomStartDate = startDate
        dailyPatternsCustomEndDate = endDate
        if dailyPatternsPeriod == .custom {
            if networkMonitor.isOnline {
                Task { await fetchRemoteHourly() }
            } else {
                Task { await fetchRemoteHourly() } // Repo handles cache fallback
            }
        }
    }
    
    func updateQualityDistributionCustomDateRange(startDate: Date, endDate: Date) {
        qualityDistributionCustomStartDate = startDate
        qualityDistributionCustomEndDate = endDate
        if qualityDistributionPeriod == .custom {
            if networkMonitor.isOnline {
                Task { await fetchRemoteDistribution() }
            } else {
                Task { await fetchRemoteDistribution() } // Repo handles cache fallback
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
