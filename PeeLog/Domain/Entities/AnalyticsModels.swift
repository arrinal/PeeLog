//
//  AnalyticsModels.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import Foundation

// MARK: - Overview

struct BasicStatistics: Sendable {
    let totalEvents: Int
    let thisWeekEvents: Int
    let averageDaily: Double
    let healthScore: Double
    let activeDays: Int  // Number of unique days with events in the period
}

// MARK: - Trends

struct QualityTrendPoint: Identifiable, Sendable {
    let date: Date
    let averageQuality: Double

    var id: Date { date }
}

// MARK: - Hourly

struct HourlyData: Identifiable, Sendable {
    let hour: Int
    let count: Int

    var id: Int { hour }
}

// MARK: - Distribution

struct QualityDistribution: Identifiable, Sendable {
    let quality: PeeQuality
    let count: Int

    var id: String { quality.rawValue }
}

// MARK: - Weekly

struct WeeklyData: Sendable {
    /// 1..7 where Sunday=1 (mirrors backend output)
    let dayOfWeek: Int
    let dayName: String
    let count: Int
    let averageQuality: Double
    /// Backend: none|poor|fair|good|excellent
    let severity: String
}

// MARK: - Insights

enum HealthInsightType: String, Sendable {
    case positive
    case info
    case warning
}

struct HealthInsight: Sendable {
    let type: HealthInsightType
    let title: String
    let message: String
    let recommendation: String?
}


