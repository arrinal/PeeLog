//
//  AIInsightRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import Foundation

/// Status of Ask AI rate limit
struct AskAIStatus: Sendable {
    let canAsk: Bool
    let hoursRemaining: Int
}

protocol AIInsightRepository: AnyObject, Sendable {
    func fetchDailyInsight() async throws -> AIInsight?
    func fetchWeeklyInsight() async throws -> AIInsight?
    func fetchCustomInsight() async throws -> AIInsight?
    func askAI(question: String) async throws -> AskAIResponse

    /// Check if user can ask AI (uses server-side 24h rolling window)
    func checkAskAIStatus() async -> AskAIStatus

    /// Save device timezone to server for timezone-aware daily insights
    func saveTimezone() async throws
}

enum AIInsightRepositoryError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case rateLimitExceeded
    case invalidResponse
    case backend(message: String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated. Please sign in to use AI insights."
        case .rateLimitExceeded:
            return "You've reached your daily AI question limit. Try again tomorrow."
        case .invalidResponse:
            return "Received an invalid response. Please try again."
        case .backend(let message):
            return message
        }
    }
}


