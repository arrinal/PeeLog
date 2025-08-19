//
//  RemoteAnalyticsService.swift
//  PeeLog
//
//  Created by Assistant on 09/08/25.
//

import Foundation
@preconcurrency import FirebaseAuth

// MARK: - Remote Analytics/Statistics Service
// Thin HTTP client for backend analytics endpoints
actor RemoteAnalyticsService {
    struct Config {
        let projectId: String
        let region: String
        let baseURL: URL
        
        init(projectId: String, region: String = "us-central1") {
            self.projectId = projectId
            self.region = region
            self.baseURL = URL(string: "https://\(region)-\(projectId).cloudfunctions.net")!
        }
    }
    
    private let config: Config
    private let urlSession: URLSession
    
    init(config: Config, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }
    
    // MARK: - Public DTOs
    struct PeriodRange: Encodable {
        let period: String // week|month|quarter|allTime|custom
        let startDate: String?
        let endDate: String?
        let timeZone: String?
        
        init(period: String, startDate: Date? = nil, endDate: Date? = nil, timeZone: TimeZone? = nil) {
            self.period = period
            if let startDate = startDate { self.startDate = ISO8601DateFormatter().string(from: startDate) } else { self.startDate = nil }
            if let endDate = endDate { self.endDate = ISO8601DateFormatter().string(from: endDate) } else { self.endDate = nil }
            self.timeZone = timeZone?.identifier
        }
    }
    
    struct StatsOverviewResponse: Codable {
        struct Interpretation: Codable {
            let label: String
            let severity: String // positive|info|warning
        }
        let totalEvents: Int
        let thisWeekEvents: Int
        let averageDaily: Double
        let healthScore: Double
        let healthScoreInterpretation: Interpretation
    }
    
    struct QualityTrendPointResponse: Codable {
        let date: String
        let averageQuality: Double
    }
    
    struct HourlyResponse: Codable {
        let hour: Int
        let count: Int
    }
    
    struct QualityDistributionResponse: Codable {
        let quality: String // clear|paleYellow|yellow|darkYellow|amber
        let count: Int
    }
    
    struct WeeklyItemResponse: Codable {
        let dayOfWeek: Int // 1..7
        let dayName: String // Sun..Sat
        let count: Int
        let averageQuality: Double
        let severity: String // none|poor|fair|good|excellent
    }
    
    struct Insight: Codable {
        let type: String // positive|info|warning
        let title: String
        let message: String
        let recommendation: String?
    }
    
    struct InsightsResponse: Codable {
        let insights: [Insight]
    }
    
    // MARK: - Public API
    func fetchStatsOverview(range: PeriodRange) async throws -> StatsOverviewResponse {
        return try await post(path: "statsOverview", body: range)
    }
    
    func fetchQualityTrends(range: PeriodRange) async throws -> [QualityTrendPointResponse] {
        return try await post(path: "qualityTrends", body: range)
    }
    
    func fetchHourly(range: PeriodRange) async throws -> [HourlyResponse] {
        return try await post(path: "hourly", body: range)
    }
    
    func fetchQualityDistribution(range: PeriodRange) async throws -> [QualityDistributionResponse] {
        return try await post(path: "qualityDistribution", body: range)
    }
    
    func fetchWeekly() async throws -> [WeeklyItemResponse] {
        // Weekly endpoint always uses last 7 days on server side
        struct EmptyBody: Encodable {}
        return try await post(path: "weekly", body: EmptyBody())
    }
    
    func fetchInsights(range: PeriodRange) async throws -> [Insight] {
        let resp: InsightsResponse = try await post(path: "insights", body: range)
        return resp.insights
    }
    
    // MARK: - Internal HTTP
    private func post<Response: Decodable, Body: Encodable>(path: String, body: Body) async throws -> Response {
        let url = config.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let token = try await fetchIDToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw URLError(.userAuthenticationRequired)
        }
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "RemoteAnalyticsService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Unknown server error"]) 
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Response.self, from: data)
    }
    
    private func fetchIDToken() async throws -> String? {
        if let user = Auth.auth().currentUser {
            return try await user.getIDToken()
        }
        return nil
    }
}


