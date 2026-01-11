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

    /// Number of active days (days with at least 1 event) in the current period.
    /// Used to determine if there's enough data for meaningful Quick Insights.
    let activeDays: Int

    let onAskAITapped: () -> Void

    private let minActiveDays = 3

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
                .foregroundColor(.blue)

            Text("AI Insights")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            if canAskAI {
                Button {
                    onAskAITapped()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        Text("Ask AI")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
                }
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
                        iconColor: .blue,
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
            } else if activeDays < minActiveDays {
                // Insufficient data - encourage user to log more
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Keep logging to get personalized insights")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Text("Log at least \(minActiveDays) days for accurate analysis")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
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

    private var relativeTimeString: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        } else {
            let days = Int(interval / 86400)
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
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
                Text(relativeTimeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let subtitle, !subtitle.isEmpty {
                Text("\"\(subtitle)\"")
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


