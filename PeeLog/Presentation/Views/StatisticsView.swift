//
//  StatisticsView.swift
//  PeeLog
//
//  Created by Arrinal S on 08/06/25.
//

import SwiftUI
import SwiftData
import Charts

@MainActor
struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: StatisticsViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    summaryCardsSection
                    qualityTrendsSection
                    dailyPatternsSection
                    qualityDistributionSection
                    weeklyOverviewSection
                    healthInsightsSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Statistics")
            .refreshable {
                viewModel.loadStatistics(context: modelContext)
            }
        }
        .onAppear {
            viewModel.loadStatistics(context: modelContext)
        }
    }
    
    private var summaryCardsSection: some View {
        VStack(spacing: 16) {
            Text("Overview")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatisticCard(
                    title: "Total Events",
                    value: "\(viewModel.totalEvents)",
                    subtitle: "All time",
                    color: .blue,
                    icon: "drop.circle.fill"
                )
                
                StatisticCard(
                    title: "This Week",
                    value: "\(viewModel.thisWeekEvents)",
                    subtitle: "Last 7 days",
                    color: .green,
                    icon: "calendar.circle.fill"
                )
                
                StatisticCard(
                    title: "Average Daily",
                    value: String(format: "%.1f", viewModel.averageDaily),
                    subtitle: "Events per day",
                    color: .orange,
                    icon: "chart.line.uptrend.xyaxis.circle.fill"
                )
                
                StatisticCard(
                    title: "Health Score",
                    value: "\(Int(viewModel.healthScore * 100))%",
                    subtitle: "Hydration level",
                    color: viewModel.healthScore > 0.7 ? .green : viewModel.healthScore > 0.4 ? .orange : .red,
                    icon: "heart.circle.fill"
                )
            }
        }
    }
    
    private var qualityTrendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quality Trends")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Menu {
                    Button("Last 7 Days") { viewModel.selectedPeriod = .week }
                    Button("Last 30 Days") { viewModel.selectedPeriod = .month }
                    Button("Last 90 Days") { viewModel.selectedPeriod = .quarter }
                } label: {
                    HStack {
                        Text(viewModel.selectedPeriod.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            if !viewModel.qualityTrendData.isEmpty {
                Chart(viewModel.qualityTrendData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Quality Score", dataPoint.averageQuality)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                }
                .frame(height: 200)
                .chartYScale(domain: 0...5)
            } else {
                EmptyChartView(message: "No quality data available")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var dailyPatternsSection: some View {
        VStack(spacing: 16) {
            Text("Daily Patterns")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !viewModel.hourlyData.isEmpty {
                Chart(viewModel.hourlyData) { dataPoint in
                    BarMark(
                        x: .value("Hour", dataPoint.hour),
                        y: .value("Count", dataPoint.count)
                    )
                    .foregroundStyle(.green)
                    .cornerRadius(4)
                }
                .frame(height: 150)
            } else {
                EmptyChartView(message: "No hourly data available")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var qualityDistributionSection: some View {
        VStack(spacing: 16) {
            Text("Quality Distribution")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !viewModel.qualityDistribution.isEmpty {
                Chart(viewModel.qualityDistribution) { dataPoint in
                    SectorMark(
                        angle: .value("Count", dataPoint.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(dataPoint.quality.color)
                    .opacity(0.8)
                }
                .frame(height: 200)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(viewModel.qualityDistribution, id: \.quality) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.quality.color)
                                .frame(width: 12, height: 12)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.quality.rawValue)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(item.count) events")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
            } else {
                EmptyChartView(message: "No quality data available")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var weeklyOverviewSection: some View {
        VStack(spacing: 16) {
            Text("Weekly Overview")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(viewModel.weeklyData, id: \.dayOfWeek) { dayData in
                    VStack(spacing: 8) {
                        Text(dayData.dayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 40, height: 40)
                            
                            Circle()
                                .fill(dayData.qualityColor)
                                .frame(width: 32, height: 32)
                            
                            Text("\(dayData.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        Text(dayData.averageQualityText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    private var healthInsightsSection: some View {
        VStack(spacing: 16) {
            Text("Health Insights")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !viewModel.healthInsights.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.healthInsights, id: \.title) { insight in
                        HealthInsightCard(insight: insight)
                    }
                }
            } else {
                Text("Loading insights...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Supporting Views
struct StatisticCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct EmptyChartView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

struct HealthInsightCard: View {
    let insight: HealthInsight
    
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(insight.type.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(insight.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let recommendation = insight.recommendation {
                Text(recommendation)
                    .font(.caption)
                    .foregroundColor(insight.type.color)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    let dependencyContainer = DependencyContainer()
    
    StatisticsView(viewModel: dependencyContainer.makeStatisticsViewModel())
        .modelContainer(container)
        .environment(\.dependencyContainer, dependencyContainer)
} 