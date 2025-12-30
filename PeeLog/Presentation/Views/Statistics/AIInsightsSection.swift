//
//  AIInsightsSection.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import SwiftUI

struct AIInsightsSection: View {
    let dailyInsight: AIInsight?
    let weeklyInsight: AIInsight?
    let customInsight: AIInsight?
    let canAskAI: Bool
    let isLoadingAI: Bool

    /// Temporary fallback: existing backend-generated health insights.
    /// These will remain visible even before Phase 5 wires real AI data.
    let legacyHealthInsights: [HealthInsight]
    let isLoadingLegacy: Bool

    let onAskAITapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            header

            if isLoadingAI {
                shimmerCards(count: 2)
            } else {
                aiCards
            }

            Divider().opacity(0.4)

            legacyInsightsBlock
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(.purple)

            Text("AI Insights")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            if canAskAI {
                Button("Ask AI") {
                    onAskAITapped()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.purple)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var aiCards: some View {
        if dailyInsight == nil, weeklyInsight == nil, customInsight == nil {
            Text("No AI insights yet. Check back tomorrow after you’ve logged some events.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        } else {
            VStack(spacing: 12) {
                if let dailyInsight {
                    AIInsightCard(
                        title: "Daily Insight",
                        icon: "sun.max.fill",
                        iconColor: .orange,
                        content: dailyInsight.content,
                        timestamp: dailyInsight.generatedAt
                    )
                }

                if let weeklyInsight {
                    AIInsightCard(
                        title: "Weekly Report",
                        icon: "calendar",
                        iconColor: .blue,
                        content: weeklyInsight.content,
                        timestamp: weeklyInsight.generatedAt
                    )
                }

                if let customInsight {
                    AIInsightCard(
                        title: "Your Question",
                        icon: "bubble.left.and.bubble.right.fill",
                        iconColor: .purple,
                        content: customInsight.content,
                        subtitle: customInsight.question,
                        timestamp: customInsight.generatedAt
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var legacyInsightsBlock: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.secondary)
                Text("Quick Insights")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }

            if isLoadingLegacy {
                shimmerCards(count: 3)
            } else if !legacyHealthInsights.isEmpty {
                VStack(spacing: 12) {
                    ForEach(legacyHealthInsights, id: \.title) { insight in
                        HealthInsightCard(insight: insight)
                    }
                }
            } else {
                Text("No quick insights yet for this range")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            }
        }
    }

    private func shimmerCards(count: Int) -> some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(height: 48)
                    .shimmering()
            }
        }
    }
}

private struct AIInsightCard: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: String
    let subtitle: String?
    let timestamp: Date

    init(
        title: String,
        icon: String,
        iconColor: Color,
        content: String,
        subtitle: String? = nil,
        timestamp: Date
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
        self.subtitle = subtitle
        self.timestamp = timestamp
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let subtitle, !subtitle.isEmpty {
                Text("“\(subtitle)”")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }

            Text(content)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}


