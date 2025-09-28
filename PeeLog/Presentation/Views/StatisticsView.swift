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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: StatisticsViewModel

    init(viewModel: StatisticsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
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
                viewModel.loadStatistics()
            }
        }
        .onAppear {
            if NetworkMonitor.shared.isOnline {
                viewModel.loadStatistics()
            } else {
                Task { await viewModel.refreshOfflineImmediate() }
            }
        }
        .onReceive(NetworkMonitor.shared.$isOnline) { isOnline in
            if isOnline && viewModel.useRemoteRefreshAllowed {
                viewModel.loadStatistics()
            } else if !isOnline {
                Task { await viewModel.refreshOfflineImmediate() }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if NetworkMonitor.shared.isOnline {
                    viewModel.refreshOnForegroundIfStale()
                } else {
                    Task { await viewModel.refreshOfflineImmediate() }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingQualityTrendsCustomDatePicker) {
            CustomDateRangeSheet(
                title: "Quality Trends Custom Range",
                startDate: $viewModel.qualityTrendsCustomStartDate,
                endDate: $viewModel.qualityTrendsCustomEndDate,
                onApply: { startDate, endDate in
                    viewModel.updateQualityTrendsCustomDateRange(startDate: startDate, endDate: endDate)
                    viewModel.showingQualityTrendsCustomDatePicker = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingDailyPatternsCustomDatePicker) {
            CustomDateRangeSheet(
                title: "Daily Patterns Custom Range",
                startDate: $viewModel.dailyPatternsCustomStartDate,
                endDate: $viewModel.dailyPatternsCustomEndDate,
                onApply: { startDate, endDate in
                    viewModel.updateDailyPatternsCustomDateRange(startDate: startDate, endDate: endDate)
                    viewModel.showingDailyPatternsCustomDatePicker = false
                }
            )
        }
        .sheet(isPresented: $viewModel.showingQualityDistributionCustomDatePicker) {
            CustomDateRangeSheet(
                title: "Quality Distribution Custom Range",
                startDate: $viewModel.qualityDistributionCustomStartDate,
                endDate: $viewModel.qualityDistributionCustomEndDate,
                onApply: { startDate, endDate in
                    viewModel.updateQualityDistributionCustomDateRange(startDate: startDate, endDate: endDate)
                    viewModel.showingQualityDistributionCustomDatePicker = false
                }
            )
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
                if viewModel.isLoadingOverview {
                    OverviewShimmerGrid()
                } else {
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
                        icon: "heart.circle.fill",
                        interpretation: viewModel.healthScoreInterpretation
                    )
                }
            }
        }
    }
    
    private var qualityTrendsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quality Trends")
                    .font(.title2)
                    .fontWeight(.bold)
                if viewModel.trendsSource != .remote {
                    Text(viewModel.trendsSource == .cache ? "Cached" : "Local")
                        .font(.caption)
                        .badgeStyle(backgroundColor: viewModel.trendsSource == .cache ? .blue : .orange)
                }
                Spacer()
                Menu {
                    Button("Last 7 Days") { viewModel.qualityTrendsPeriod = .week }
                    Button("Last 30 Days") { viewModel.qualityTrendsPeriod = .month }
                    Button("Last 90 Days") { viewModel.qualityTrendsPeriod = .quarter }
                    Button("All Time") { viewModel.qualityTrendsPeriod = .allTime }
                    Button("Custom Range") { 
                        viewModel.qualityTrendsPeriod = .custom
                        viewModel.showingQualityTrendsCustomDatePicker = true
                    }
                } label: {
                    HStack {
                        Text(viewModel.qualityTrendsPeriod.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Text("Track your hydration quality over time. A higher quality score indicates better hydration, while declining trends may suggest you need to drink more water.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoadingTrends {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 200)
                    .shimmering()
            } else if !viewModel.qualityTrendData.isEmpty {
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
            HStack {
                Text("Daily Patterns")
                    .font(.title2)
                    .fontWeight(.bold)
                if viewModel.hourlySource != .remote {
                    Text(viewModel.hourlySource == .cache ? "Cached" : "Local")
                        .font(.caption)
                        .badgeStyle(backgroundColor: viewModel.hourlySource == .cache ? .blue : .orange)
                }
                Spacer()
                Menu {
                    Button("Last 7 Days") { viewModel.dailyPatternsPeriod = .week }
                    Button("Last 30 Days") { viewModel.dailyPatternsPeriod = .month }
                    Button("Last 90 Days") { viewModel.dailyPatternsPeriod = .quarter }
                    Button("All Time") { viewModel.dailyPatternsPeriod = .allTime }
                    Button("Custom Range") { 
                        viewModel.dailyPatternsPeriod = .custom
                        viewModel.showingDailyPatternsCustomDatePicker = true
                    }
                } label: {
                    HStack {
                        Text(viewModel.dailyPatternsPeriod.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Text("Discover when you urinate most frequently throughout the day. This helps identify your natural rhythm and optimal hydration timing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoadingHourly {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(height: 150)
                    .shimmering()
            } else if !viewModel.hourlyData.isEmpty {
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
            HStack {
                Text("Quality Distribution")
                    .font(.title2)
                    .fontWeight(.bold)
                if viewModel.distributionSource != .remote {
                    Text(viewModel.distributionSource == .cache ? "Cached" : "Local")
                        .font(.caption)
                        .badgeStyle(backgroundColor: viewModel.distributionSource == .cache ? .blue : .orange)
                }
                Spacer()
                Menu {
                    Button("Last 7 Days") { viewModel.qualityDistributionPeriod = .week }
                    Button("Last 30 Days") { viewModel.qualityDistributionPeriod = .month }
                    Button("Last 90 Days") { viewModel.qualityDistributionPeriod = .quarter }
                    Button("All Time") { viewModel.qualityDistributionPeriod = .allTime }
                    Button("Custom Range") { 
                        viewModel.qualityDistributionPeriod = .custom
                        viewModel.showingQualityDistributionCustomDatePicker = true
                    }
                } label: {
                    HStack {
                        Text(viewModel.qualityDistributionPeriod.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            
            Text("See the breakdown of your hydration quality levels. A healthy distribution should have more clear and light yellow events than dark yellow or amber ones.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoadingDistribution {
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .shimmering()
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(0..<4, id: \.self) { _ in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 12, height: 12)
                                    .shimmering()
                                VStack(alignment: .leading, spacing: 2) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 80, height: 10)
                                        .shimmering()
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 60, height: 8)
                                        .shimmering()
                                }
                                Spacer()
                            }
                        }
                    }
                }
            } else if !viewModel.qualityDistribution.isEmpty {
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
            if viewModel.weeklySource != .remote {
                Text(viewModel.weeklySource == .cache ? "Cached" : "Local")
                    .font(.caption)
                    .badgeStyle(backgroundColor: viewModel.weeklySource == .cache ? .blue : .orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Text("Your weekly activity at a glance. Each day shows the number of events and average quality, helping you spot patterns across the week.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.isLoadingWeekly {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(0..<7, id: \.self) { _ in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 10)
                                .shimmering()
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 40, height: 40)
                                .shimmering()
                        }
                    }
                }
            } else {
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
                        }
                    }
                }
            }
            
            // Color legend
            VStack(spacing: 8) {
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 12, height: 12)
                        Text("No data")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                        Text("Poor hydration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 12, height: 12)
                        Text("Fair hydration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 12, height: 12)
                        Text("Good hydration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                        Text("Excellent hydration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.top, 8)
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
            if viewModel.insightsSource != .remote {
                Text(viewModel.insightsSource == .cache ? "Cached" : "Local")
                    .font(.caption)
                    .badgeStyle(backgroundColor: viewModel.insightsSource == .cache ? .blue : .orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if viewModel.isLoadingInsights {
                VStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                            .frame(height: 48)
                            .shimmering()
                    }
                }
            } else if !viewModel.healthInsights.isEmpty {
                VStack(spacing: 12) {
                    ForEach(viewModel.healthInsights, id: \.title) { insight in
                        HealthInsightCard(insight: insight)
                    }
                }
            } else {
                Text("No insights yet for this range")
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
    let interpretation: String?
    
    init(title: String, value: String, subtitle: String, color: Color, icon: String, interpretation: String? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.icon = icon
        self.interpretation = interpretation
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                if let interpretation = interpretation {
                    Spacer()
                    Text(interpretation)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(color.opacity(0.2))
                        )
                } else {
                    Spacer()
                }
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
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

// MARK: - Shimmers
private struct OverviewShimmerGrid: View {
    var body: some View {
        Group {
            ShimmerCard()
            ShimmerCard()
            ShimmerCard()
            ShimmerCard()
        }
    }
}

private struct ShimmerCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 20, height: 20)
                    .shimmering()
                Spacer()
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .frame(width: 60)
                    .shimmering()
            }
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 24)
                    .shimmering()
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 12)
                    .shimmering()
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 10)
                    .frame(maxWidth: 120)
                    .shimmering()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
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

// MARK: - Custom Date Range Sheet
struct CustomDateRangeSheet: View {
    let title: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    let onApply: (Date, Date) -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Select a custom date range for analysis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start Date")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            DatePicker(
                                "",
                                selection: $startDate,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .accentColor(.blue)
                        }
                        .padding()
                        .background(cardBackground)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("End Date")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            DatePicker(
                                "",
                                selection: $endDate,
                                in: startDate...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .accentColor(.blue)
                        }
                        .padding()
                        .background(cardBackground)
                    }
                    
                    Button(action: {
                        onApply(startDate, endDate)
                    }) {
                        Text("Apply Date Range")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.blue)
                                    .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                            )
                    }
                    .padding(.top, 12)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                }
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? 
                    Color(red: 0.05, green: 0.05, blue: 0.08) : 
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                colorScheme == .dark ? 
                    Color(red: 0.08, green: 0.08, blue: 0.12) : 
                    Color(red: 0.90, green: 0.95, blue: 0.99)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? 
                    Color.white.opacity(0.05) : 
                    Color.black.opacity(0.06), 
                radius: 8, 
                x: 0, 
                y: 2
            )
    }
}

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    let dependencyContainer = DependencyContainer()
    
    StatisticsView(viewModel: dependencyContainer.makeStatisticsViewModel(modelContext: container.mainContext))
        .modelContainer(container)
        .environment(\.dependencyContainer, dependencyContainer)
} 
 