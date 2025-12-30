//
//  AIInsight.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import Foundation

enum AIInsightType: String, Codable, Sendable {
    case daily
    case weekly
    case custom
}

struct AIInsight: Codable, Sendable {
    let type: AIInsightType
    let content: String
    let generatedAt: Date
    let question: String?
}

struct AskAIResponse: Codable, Sendable {
    let insight: String
}


