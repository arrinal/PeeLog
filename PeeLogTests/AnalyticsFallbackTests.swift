//
//  AnalyticsFallbackTests.swift
//  PeeLogTests
//
//

import Foundation
import Testing
import Combine
@testable import PeeLog

// Simple stub service to simulate RemoteAnalyticsService behavior via the repository
final class StubAnalyticsRepository: AnalyticsRepository, @unchecked Sendable {
    enum Mode { case remote, cache, failure }
    let mode: Mode

    init(mode: Mode) { self.mode = mode }

    func fetchOverview(range: AnalyticsRange) async throws -> Sourced<OverviewFromServer> {
        switch mode {
        case .remote:
            return Sourced(data: .init(stats: .init(totalEvents: 10, thisWeekEvents: 3, averageDaily: 1.0, healthScore: 0.8, activeDays: 3), interpretationLabel: "Good", interpretationSeverity: "info"), source: .remote)
        case .cache:
            return Sourced(data: .init(stats: .init(totalEvents: 8, thisWeekEvents: 2, averageDaily: 0.8, healthScore: 0.7, activeDays: 2), interpretationLabel: "Cached", interpretationSeverity: "info"), source: .cache)
        case .failure:
            struct E: Error {}
            throw E()
        }
    }

    func fetchQualityTrends(range: AnalyticsRange) async throws -> Sourced<[QualityTrendPoint]> {
        switch mode {
        case .remote: return Sourced(data: [QualityTrendPoint(date: Date(), averageQuality: 3.0)], source: .remote)
        case .cache:  return Sourced(data: [QualityTrendPoint(date: Date(), averageQuality: 2.5)], source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }

    func fetchHourly(range: AnalyticsRange) async throws -> Sourced<[HourlyData]> {
        switch mode {
        case .remote: return Sourced(data: [HourlyData(hour: 9, count: 2)], source: .remote)
        case .cache:  return Sourced(data: [HourlyData(hour: 10, count: 1)], source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }

    func fetchQualityDistribution(range: AnalyticsRange) async throws -> Sourced<[QualityDistribution]> {
        switch mode {
        case .remote: return Sourced(data: [QualityDistribution(quality: .paleYellow, count: 5)], source: .remote)
        case .cache:  return Sourced(data: [QualityDistribution(quality: .yellow, count: 3)], source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }

    func fetchWeekly() async throws -> Sourced<[WeeklyData]> {
        switch mode {
        case .remote: return Sourced(data: [WeeklyData(dayOfWeek: 1, dayName: "Mon", count: 1, averageQuality: 3.0, severity: "info")], source: .remote)
        case .cache:  return Sourced(data: [WeeklyData(dayOfWeek: 2, dayName: "Tue", count: 1, averageQuality: 2.0, severity: "info")], source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }

    func fetchInsights(range: AnalyticsRange) async throws -> Sourced<[HealthInsight]> {
        switch mode {
        case .remote: return Sourced(data: [HealthInsight(type: .info, title: "Hydrate", message: "Drink water", recommendation: nil)], source: .remote)
        case .cache:  return Sourced(data: [HealthInsight(type: .info, title: "Cached", message: "Cached msg", recommendation: nil)], source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }

    func fetchDailyQualitySummaries(range: AnalyticsRange) async throws -> Sourced<[DailyQualitySummary]> {
        let sample = [
            DailyQualitySummary(id: "2026-01-01", date: Date(), eventCount: 1, label: "Good", color: "green")
        ]
        switch mode {
        case .remote: return Sourced(data: sample, source: .remote)
        case .cache:  return Sourced(data: sample, source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }
}

final class StubAIInsightRepository: AIInsightRepository, @unchecked Sendable {
    func fetchDailyInsight() async throws -> AIInsight? { nil }
    func fetchWeeklyInsight() async throws -> AIInsight? { nil }
    func fetchCustomInsight() async throws -> AIInsight? { nil }
    func askAI(question: String) async throws -> AskAIResponse { AskAIResponse(insight: "") }
    func checkAskAIStatus() async -> AskAIStatus { AskAIStatus(canAsk: true, hoursRemaining: 0) }
    func saveTimezone() async throws {}
}

@MainActor
struct AnalyticsFallbackTests {

    private func makeViewModel(repo: AnalyticsRepository) -> StatisticsViewModel {
        return StatisticsViewModel(analyticsRepository: repo, aiInsightRepository: StubAIInsightRepository())
    }

    @Test func loadsFromRemoteWhenAvailable() async throws {
        let stub = StubAnalyticsRepository(mode: .remote)
        let vm = makeViewModel(repo: stub)
        vm.loadStatistics()
        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(vm.overviewSource == .remote)
        #expect(vm.trendsSource == .remote)
        #expect(vm.hourlySource == .remote)
        #expect(vm.distributionSource == .remote)
        #expect(vm.weeklySource == .remote)
        #expect(vm.insightsSource == .remote)
    }

    @Test func fallsBackToCacheWhenRemoteFails() async throws {
        // Simulate repository serving cached responses
        let stub = StubAnalyticsRepository(mode: .cache)
        let vm = makeViewModel(repo: stub)
        vm.loadStatistics()
        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(vm.overviewSource == .cache)
        #expect(vm.trendsSource == .cache)
        #expect(vm.hourlySource == .cache)
        #expect(vm.distributionSource == .cache)
        #expect(vm.weeklySource == .cache)
        #expect(vm.insightsSource == .cache)
    }

    @Test func handlesTotalFailure() async throws {
        // Simulate total failure; VM should report source as .cache (meaning unavailable/stale)
        // We removed local fallback, so it should NOT be .local
        let failingRepo = StubAnalyticsRepository(mode: .failure)
        let vm = makeViewModel(repo: failingRepo)
        vm.loadStatistics()
        try await Task.sleep(nanoseconds: 600_000_000)
        
        // In the new implementation, failure defaults to .cache
        #expect(vm.overviewSource == .cache)
        #expect(vm.trendsSource == .cache)
        #expect(vm.hourlySource == .cache)
        #expect(vm.distributionSource == .cache)
        #expect(vm.weeklySource == .cache)
        #expect(vm.insightsSource == .cache)
    }
}
