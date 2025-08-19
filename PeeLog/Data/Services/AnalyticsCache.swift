//
//  AnalyticsCache.swift
//  PeeLog
//
//  Lightweight disk cache for analytics responses to support offline mode.
//

import Foundation

actor AnalyticsCache {
    private let fileManager = FileManager.default

    private func baseDirectory(for uid: String) throws -> URL {
        let caches = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = caches.appendingPathComponent("PeeLogAnalyticsCache", isDirectory: true).appendingPathComponent(uid, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic])
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }

    private func key(period: String, startISO: String?, endISO: String?, tz: String?) -> String {
        let s = startISO ?? "-"
        let e = endISO ?? "-"
        let t = tz ?? "-"
        // Avoid very long filenames by hashing the long parts
        let raw = "\(period)|\(s)|\(e)|\(t)"
        let hash = String(raw.hashValue)
        return hash
    }

    // MARK: - Overview
    func saveOverview(uid: String, period: String, startISO: String?, endISO: String?, tz: String?, response: RemoteAnalyticsService.StatsOverviewResponse) async throws {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("overview_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        try write(response, to: url)
    }

    func loadOverview(uid: String, period: String, startISO: String?, endISO: String?, tz: String?) async throws -> RemoteAnalyticsService.StatsOverviewResponse? {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("overview_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try read(RemoteAnalyticsService.StatsOverviewResponse.self, from: url)
    }

    // MARK: - Trends
    func saveQualityTrends(uid: String, period: String, startISO: String?, endISO: String?, tz: String?, response: [RemoteAnalyticsService.QualityTrendPointResponse]) async throws {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("trends_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        try write(response, to: url)
    }

    func loadQualityTrends(uid: String, period: String, startISO: String?, endISO: String?, tz: String?) async throws -> [RemoteAnalyticsService.QualityTrendPointResponse]? {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("trends_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try read([RemoteAnalyticsService.QualityTrendPointResponse].self, from: url)
    }

    // MARK: - Hourly
    func saveHourly(uid: String, period: String, startISO: String?, endISO: String?, tz: String?, response: [RemoteAnalyticsService.HourlyResponse]) async throws {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("hourly_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        try write(response, to: url)
    }

    func loadHourly(uid: String, period: String, startISO: String?, endISO: String?, tz: String?) async throws -> [RemoteAnalyticsService.HourlyResponse]? {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("hourly_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try read([RemoteAnalyticsService.HourlyResponse].self, from: url)
    }

    // MARK: - Distribution
    func saveQualityDistribution(uid: String, period: String, startISO: String?, endISO: String?, tz: String?, response: [RemoteAnalyticsService.QualityDistributionResponse]) async throws {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("distribution_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        try write(response, to: url)
    }

    func loadQualityDistribution(uid: String, period: String, startISO: String?, endISO: String?, tz: String?) async throws -> [RemoteAnalyticsService.QualityDistributionResponse]? {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("distribution_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try read([RemoteAnalyticsService.QualityDistributionResponse].self, from: url)
    }

    // MARK: - Weekly (no range)
    func saveWeekly(uid: String, response: [RemoteAnalyticsService.WeeklyItemResponse]) async throws {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("weekly.json")
        try write(response, to: url)
    }

    func loadWeekly(uid: String) async throws -> [RemoteAnalyticsService.WeeklyItemResponse]? {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("weekly.json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try read([RemoteAnalyticsService.WeeklyItemResponse].self, from: url)
    }

    // MARK: - Insights
    func saveInsights(uid: String, period: String, startISO: String?, endISO: String?, tz: String?, response: [RemoteAnalyticsService.Insight]) async throws {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("insights_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        try write(response, to: url)
    }

    func loadInsights(uid: String, period: String, startISO: String?, endISO: String?, tz: String?) async throws -> [RemoteAnalyticsService.Insight]? {
        let dir = try baseDirectory(for: uid)
        let url = dir.appendingPathComponent("insights_\(key(period: period, startISO: startISO, endISO: endISO, tz: tz)).json")
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try read([RemoteAnalyticsService.Insight].self, from: url)
    }
}


