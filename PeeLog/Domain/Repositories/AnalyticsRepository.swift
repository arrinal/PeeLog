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
    func fetchDailyQualitySummaries(range: AnalyticsRange) async throws -> Sourced<[DailyQualitySummary]>
}

// MARK: - Daily Quality Summary (for History View)
struct DailyQualitySummary: Identifiable, Sendable {
    let id: String // ISO date string
    let date: Date
    let eventCount: Int
    let label: String
    let color: String

    var displayColor: SwiftUI.Color {
        switch color {
        case "green": return .green
        case "lightGreen": return SwiftUI.Color(red: 0.6, green: 0.8, blue: 0.2)
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        case "yellowOrange": return SwiftUI.Color(red: 0.8, green: 0.6, blue: 0.2)
        default: return .gray
        }
    }
}

import SwiftUI

// MARK: - Overview DTO from server
struct OverviewFromServer {
    let stats: BasicStatistics
    let interpretationLabel: String
    let interpretationSeverity: String // positive|info|warning
}

// MARK: - Errors

enum AnalyticsRepositoryError: Error, Sendable {
    case notAuthenticated
    case noCacheAvailable(section: AnalyticsSection, underlyingDescription: String)
}


