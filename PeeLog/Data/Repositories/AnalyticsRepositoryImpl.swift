//
//  AnalyticsRepositoryImpl.swift
//  PeeLog
//
//  Created by Assistant on 09/08/25.
//

import Foundation
@preconcurrency import FirebaseAuth

@MainActor
final class AnalyticsRepositoryImpl: AnalyticsRepository {
    private let service: RemoteAnalyticsService
    private let cache: AnalyticsCache
    
    init(service: RemoteAnalyticsService, cache: AnalyticsCache = AnalyticsCache()) {
        self.service = service
        self.cache = cache
    }
    
    private func toPeriodRange(_ range: AnalyticsRange) -> RemoteAnalyticsService.PeriodRange {
        let p: String
        switch range.period {
        case .week: p = "week"
        case .month: p = "month"
        case .quarter: p = "quarter"
        case .allTime: p = "allTime"
        case .custom: p = "custom"
        case .today, .yesterday, .last3Days, .lastWeek, .lastMonth:
            // Map miscellaneous variants to week unless explicitly custom
            p = "week"
        }
        return .init(period: p, startDate: range.startDate, endDate: range.endDate, timeZone: range.timeZone)
    }
    
    func fetchOverview(range: AnalyticsRange) async throws -> OverviewFromServer {
        let pr = toPeriodRange(range)
        let uid = await AuthHelper.currentUid() ?? "guest"
        do {
            let resp = try await service.fetchStatsOverview(range: pr)
            try await cache.saveOverview(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone, response: resp)
            let stats = BasicStatistics(
                totalEvents: resp.totalEvents,
                thisWeekEvents: resp.thisWeekEvents,
                averageDaily: resp.averageDaily,
                healthScore: resp.healthScore
            )
            return OverviewFromServer(
                stats: stats,
                interpretationLabel: resp.healthScoreInterpretation.label,
                interpretationSeverity: resp.healthScoreInterpretation.severity
            )
        } catch {
            if let cached = try await cache.loadOverview(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone) {
                let stats = BasicStatistics(
                    totalEvents: cached.totalEvents,
                    thisWeekEvents: cached.thisWeekEvents,
                    averageDaily: cached.averageDaily,
                    healthScore: cached.healthScore
                )
                return OverviewFromServer(
                    stats: stats,
                    interpretationLabel: cached.healthScoreInterpretation.label,
                    interpretationSeverity: cached.healthScoreInterpretation.severity
                )
            }
            throw error
        }
    }
    
    func fetchQualityTrends(range: AnalyticsRange) async throws -> [QualityTrendPoint] {
        let pr = toPeriodRange(range)
        let uid = await AuthHelper.currentUid() ?? "guest"
        do {
            let resp = try await service.fetchQualityTrends(range: pr)
            try await cache.saveQualityTrends(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone, response: resp)
            return resp.map { .init(date: ISO8601DateFormatter().date(from: $0.date) ?? Date(), averageQuality: $0.averageQuality) }
        } catch {
            if let cached = try await cache.loadQualityTrends(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone) {
                return cached.map { .init(date: ISO8601DateFormatter().date(from: $0.date) ?? Date(), averageQuality: $0.averageQuality) }
            }
            throw error
        }
    }
    
    func fetchHourly(range: AnalyticsRange) async throws -> [HourlyData] {
        let pr = toPeriodRange(range)
        let uid = await AuthHelper.currentUid() ?? "guest"
        do {
            let resp = try await service.fetchHourly(range: pr)
            try await cache.saveHourly(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone, response: resp)
            return resp.map { .init(hour: $0.hour, count: $0.count) }
        } catch {
            if let cached = try await cache.loadHourly(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone) {
                return cached.map { .init(hour: $0.hour, count: $0.count) }
            }
            throw error
        }
    }
    
    func fetchQualityDistribution(range: AnalyticsRange) async throws -> [QualityDistribution] {
        let pr = toPeriodRange(range)
        let uid = await AuthHelper.currentUid() ?? "guest"
        func map(_ list: [RemoteAnalyticsService.QualityDistributionResponse]) -> [QualityDistribution] {
            return list.compactMap { item in
            let quality: PeeQuality
            switch item.quality {
            case "clear": quality = .clear
            case "paleYellow": quality = .paleYellow
            case "yellow": quality = .yellow
            case "darkYellow": quality = .darkYellow
            case "amber": quality = .amber
            default: return nil
            }
            return QualityDistribution(quality: quality, count: item.count)
            }
        }
        do {
            let resp = try await service.fetchQualityDistribution(range: pr)
            try await cache.saveQualityDistribution(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone, response: resp)
            return map(resp)
        } catch {
            if let cached = try await cache.loadQualityDistribution(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone) {
                return map(cached)
            }
            throw error
        }
    }
    
    func fetchWeekly() async throws -> [WeeklyData] {
        let uid = await AuthHelper.currentUid() ?? "guest"
        do {
            let resp = try await service.fetchWeekly()
            try await cache.saveWeekly(uid: uid, response: resp)
            return resp.map { .init(dayOfWeek: $0.dayOfWeek, dayName: $0.dayName, count: $0.count, averageQuality: $0.averageQuality, severity: $0.severity) }
        } catch {
            if let cached = try await cache.loadWeekly(uid: uid) {
                return cached.map { .init(dayOfWeek: $0.dayOfWeek, dayName: $0.dayName, count: $0.count, averageQuality: $0.averageQuality, severity: $0.severity) }
            }
            throw error
        }
    }
    
    func fetchInsights(range: AnalyticsRange) async throws -> [HealthInsight] {
        let pr = toPeriodRange(range)
        let uid = await AuthHelper.currentUid() ?? "guest"
        func map(_ items: [RemoteAnalyticsService.Insight]) -> [HealthInsight] {
            return items.map { item in
            let type: HealthInsightType
            switch item.type {
            case "positive": type = .positive
            case "info": type = .info
            case "warning": type = .warning
            default: type = .info
            }
            return HealthInsight(type: type, title: item.title, message: item.message, recommendation: item.recommendation)
            }
        }
        do {
            let items = try await service.fetchInsights(range: pr)
            try await cache.saveInsights(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone, response: items)
            return map(items)
        } catch {
            if let cached = try await cache.loadInsights(uid: uid, period: pr.period, startISO: pr.startDate, endISO: pr.endDate, tz: pr.timeZone) {
                return map(cached)
            }
            throw error
        }
    }
}

// MARK: - Auth Helper
private enum AuthHelper {
    static func currentUid() async -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
}


