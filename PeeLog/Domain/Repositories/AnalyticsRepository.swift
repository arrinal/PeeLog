//
//  AnalyticsRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 09/08/25.
//

import Foundation

// MARK: - Remote Analytics Range (Domain)
struct AnalyticsRange {
    let period: TimePeriod
    let startDate: Date?
    let endDate: Date?
    let timeZone: TimeZone?
    
    init(period: TimePeriod, startDate: Date? = nil, endDate: Date? = nil, timeZone: TimeZone? = nil) {
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.timeZone = timeZone
    }
}

// MARK: - Analytics Repository Protocol (Sendable, non-main-actor)
protocol AnalyticsRepository: AnyObject, Sendable {
    func fetchOverview(range: AnalyticsRange) async throws -> Sourced<OverviewFromServer>
    func fetchQualityTrends(range: AnalyticsRange) async throws -> Sourced<[QualityTrendPoint]>
    func fetchHourly(range: AnalyticsRange) async throws -> Sourced<[HourlyData]>
    func fetchQualityDistribution(range: AnalyticsRange) async throws -> Sourced<[QualityDistribution]>
    func fetchWeekly() async throws -> Sourced<[WeeklyData]>
    func fetchInsights(range: AnalyticsRange) async throws -> Sourced<[HealthInsight]>
}

// MARK: - Overview DTO from server
struct OverviewFromServer {
    let stats: BasicStatistics
    let interpretationLabel: String
    let interpretationSeverity: String // positive|info|warning
}


