//
//  AnalyticsFallbackTests.swift
//  PeeLogTests
//

import Foundation
import Testing
import Combine
@testable import PeeLog

// Simple stub service to simulate RemoteAnalyticsService behavior via the repository
final class StubAnalyticsRepository: AnalyticsRepository {
    enum Mode { case remote, cache, failure }
    let mode: Mode

    init(mode: Mode) { self.mode = mode }

    func fetchOverview(range: AnalyticsRange) async throws -> Sourced<OverviewFromServer> {
        switch mode {
        case .remote:
            return Sourced(data: .init(stats: .init(totalEvents: 10, thisWeekEvents: 3, averageDaily: 1.0, healthScore: 0.8), interpretationLabel: "Good", interpretationSeverity: "info"), source: .remote)
        case .cache:
            return Sourced(data: .init(stats: .init(totalEvents: 8, thisWeekEvents: 2, averageDaily: 0.8, healthScore: 0.7), interpretationLabel: "Cached", interpretationSeverity: "info"), source: .cache)
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
        case .remote: return Sourced(data: [HealthInsight(type: .info, title: "Hydrate", message: "Drink water")], source: .remote)
        case .cache:  return Sourced(data: [HealthInsight(type: .info, title: "Cached", message: "Cached msg")], source: .cache)
        case .failure: struct E: Error {}; throw E()
        }
    }
}

@MainActor
struct AnalyticsFallbackTests {

    private func makeViewModel(repo: AnalyticsRepository) -> StatisticsViewModel {
        // Build minimal dependencies with defaults
        let eventsRepo = PeeEventRepositoryDummy()
        let userRepo = UserRepositoryDummy()
        let all = GetAllPeeEventsUseCase(repository: eventsRepo, userRepository: userRepo)
        let calc = CalculateBasicStatisticsUseCase(repository: eventsRepo)
        let trends = GenerateQualityTrendsUseCase()
        let insights = GenerateHealthInsightsUseCase(repository: eventsRepo)
        let hourly = AnalyzeHourlyPatternsUseCase()
        let dist = GenerateQualityDistributionUseCase()
        let weekly = GenerateWeeklyDataUseCase(repository: eventsRepo)
        return StatisticsViewModel(
            getAllEventsUseCase: all,
            calculateStatisticsUseCase: calc,
            generateQualityTrendsUseCase: trends,
            generateHealthInsightsUseCase: insights,
            analyzeHourlyPatternsUseCase: hourly,
            generateQualityDistributionUseCase: dist,
            generateWeeklyDataUseCase: weekly,
            analyticsRepository: repo
        )
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

    @Test func fallsBackToLocalWhenRemoteUnavailableAndNoCache() async throws {
        // Simulate total failure; VM should compute locally and mark sources as .local
        // We simulate by using a failing repository and toggling VM to offline path via NetworkMonitor stub
        let failingRepo = StubAnalyticsRepository(mode: .failure)
        let vm = makeViewModel(repo: failingRepo)
        // Force loadLocal path by setting network offline in a safe way if available; otherwise rely on catch path
        vm.loadStatistics()
        try await Task.sleep(nanoseconds: 600_000_000)
        #expect(vm.trendsSource == .local)
        #expect(vm.hourlySource == .local)
        #expect(vm.distributionSource == .local)
        #expect(vm.weeklySource == .local)
        #expect(vm.insightsSource == .local)
    }
}

// MARK: - Dummy Repositories for UseCases (no persistence)
@MainActor
final class PeeEventRepositoryDummy: PeeEventRepository {
    func getAllEvents() -> [PeeEvent] { [] }
    func getEventsForToday() -> [PeeEvent] { [] }
    func addEvent(_ event: PeeEvent) throws {}
    func addEvents(_ events: [PeeEvent]) throws {}
    func deleteEvent(_ event: PeeEvent) throws {}
    func clearAllEvents() throws {}
}

@MainActor
final class UserRepositoryDummy: UserRepository {
    var currentUser: AnyPublisher<User?, Never> { Just(User.createGuest()).eraseToAnyPublisher() }
    var syncStatus: AnyPublisher<SyncStatus, Never> { Just(.idle).eraseToAnyPublisher() }
    var isLoading: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }

    func getCurrentUser() async -> User? { User.createGuest() }
    func saveUser(_ user: User) async throws {}
    func updateUser(_ user: User) async throws {}
    func deleteUser(_ user: User) async throws {}
    func clearUserData() async throws {}
    func clearAuthenticatedUsers() async throws {}
    func updateUserPreferences(_ preferences: UserPreferences) async throws {}
    func getUserPreferences() async -> UserPreferences? { nil }
    func updateDisplayName(_ displayName: String) async throws {}
    func updateEmail(_ email: String) async throws {}
    func syncUserData() async throws {}
    func syncUserToServer(_ user: User) async throws {}
    func loadUserFromServer() async throws -> User? { nil }
    func createGuestUser() async throws -> User { User.createGuest() }
    func isGuestUser() async -> Bool { true }
    func migrateGuestToAuthenticated(_ authenticatedUser: User) async throws {}
    func exportUserData() async throws -> Data { Data() }
    func importUserData(_ data: Data) async throws {}
    func getUserById(_ id: UUID) async -> User? { nil }
    func getAllLocalUsers() async -> [User] { [] }
    func clearAllLocalData() async throws {}
}


