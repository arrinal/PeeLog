//
//  AnalyticsModels+UI.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import SwiftUI

extension WeeklyData {
    var qualityColor: Color {
        switch severity {
        case "excellent": return .green
        case "good": return .yellow
        case "fair": return .orange
        case "poor": return .red
        default: return Color(.systemGray4)
        }
    }
}

extension HealthInsightType {
    var color: Color {
        switch self {
        case .positive: return .green
        case .info: return .blue
        case .warning: return .orange
        }
    }
}


