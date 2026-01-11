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
    @State private var isAskAISheetPresented: Bool = false

    init(viewModel: StatisticsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if shouldShowNoCacheEmptyStateBanner {
                        noCacheEmptyStateBanner
                    } else if viewModel.isDataStale {
                        staleDataBanner
                    }

                    summaryCardsSection
                    aiInsightsSection
                    qualityTrendsSection
                    dailyPatternsSection
                    qualityDistributionSection
                    weeklyOverviewSection

                    medicalDisclaimerSection
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let lastSynced = viewModel.lastSyncedAt {
                        Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 5)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.loadStatistics()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh statistics")
                }
            }
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
            viewModel.loadAIInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsStoreWillReset)) { _ in
            Task { @MainActor in
                // Clear charts and counters to avoid using detached objects
                viewModel.totalEvents = 0
                viewModel.thisWeekEvents = 0
                viewModel.averageDaily = 0
                viewModel.healthScore = 0
                viewModel.qualityTrendData = []
                viewModel.hourlyData = []
                viewModel.qualityDistribution = []
                viewModel.weeklyData = []
                viewModel.healthInsights = []
                viewModel.showingQualityTrendsCustomDatePicker = false
                viewModel.showingDailyPatternsCustomDatePicker = false
                viewModel.showingQualityDistributionCustomDatePicker = false
                viewModel.showingAverageDailyCustomDatePicker = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsStoreDidReset)) { _ in
            Task { @MainActor in
                if NetworkMonitor.shared.isOnline {
                    viewModel.loadStatistics()
                } else {
                    await viewModel.refreshOfflineImmediate()
                }
            }
        }
        .onReceive(NetworkMonitor.shared.$isOnline) { isOnline in
            if isOnline {
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
        .sheet(isPresented: $viewModel.showingAverageDailyCustomDatePicker) {
            CustomDateRangeSheet(
                title: "Average Daily Custom Range",
                startDate: $viewModel.averageDailyCustomStartDate,
                endDate: $viewModel.averageDailyCustomEndDate,
                onApply: { startDate, endDate in
                    viewModel.updateAverageDailyCustomDateRange(startDate: startDate, endDate: endDate)
                    viewModel.showingAverageDailyCustomDatePicker = false
                }
            )
        }
        .sheet(isPresented: $isAskAISheetPresented) {
            AskAISheet(
                canAskAI: viewModel.canAskAI,
                onSubmit: { question in
                    try await viewModel.askAI(question: question)
                }
            )
        }
    }
    
    private var shouldShowNoCacheEmptyStateBanner: Bool {
        // If we've never successfully synced from the backend, we can't show useful offline stats.
        return !NetworkMonitor.shared.isOnline && viewModel.lastSyncedAt == nil
    }
    
    private var noCacheEmptyStateBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline - No cached stats yet")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Text("Connect to the internet and refresh once to enable offline viewing.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Refresh") {
                viewModel.loadStatistics()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .disabled(!NetworkMonitor.shared.isOnline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
    
    private var staleDataBanner: some View {
        let isOnline = NetworkMonitor.shared.isOnline
        return HStack(spacing: 12) {
            Image(systemName: isOnline ? "clock.arrow.circlepath" : "exclamationmark.triangle.fill")
                .foregroundColor(isOnline ? .blue : .yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isOnline ? "Some data is cached" : "Offline Mode")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                if let lastSynced = viewModel.lastSyncedAt {
                    Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Showing cached data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Refresh") {
                viewModel.loadStatistics()
            }
            .font(.caption)
            .buttonStyle(.bordered)
            .disabled(!isOnline)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke((isOnline ? Color.blue : Color.yellow).opacity(0.25), lineWidth: 1)
        )
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
                    
                    AverageDailyCard(
                        value: viewModel.averageDaily,
                        activeDays: viewModel.averageDailyActiveDays,
                        period: $viewModel.averageDailyPeriod,
                        isLoading: viewModel.isLoadingAverageDaily,
                        onCustomRangeTap: {
                            viewModel.showingAverageDailyCustomDatePicker = true
                        }
                    )
                    
                    HealthScoreCard(
                        healthScore: viewModel.healthScore,
                        activeDays: viewModel.activeDays,
                        interpretation: viewModel.healthScoreInterpretation,
                        isLoading: viewModel.isLoadingOverview
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
                let dataCount = viewModel.qualityTrendData.count
                let showPoints = dataCount <= 15

                Chart(viewModel.qualityTrendData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Quality", dataPoint.averageQuality)
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    if showPoints {
                        PointMark(
                            x: .value("Date", dataPoint.date),
                            y: .value("Quality", dataPoint.averageQuality)
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(40)
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...6)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: min(dataCount, 5))) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatDateForAxis(date, dataCount: dataCount))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: [1, 2, 3, 4, 5]) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(qualityScoreLabel(for: v))
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }

                // Chart legend
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Higher = Better (5 = Pale Yellow, 1 = Amber)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                EmptyChartView(message: "No quality data available")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func qualityScoreLabel(for value: Int) -> String {
        // Evenly spaced scale: 5=Pale(best), 4=Clear, 3=Yellow, 2=Dark, 1=Amber(worst)
        switch value {
        case 5: return "Pale"
        case 4: return "Clear"
        case 3: return "Yellow"
        case 2: return "Dark"
        case 1: return "Amber"
        default: return "\(value)"
        }
    }

    private func formatDateForAxis(_ date: Date, dataCount: Int) -> String {
        let formatter = DateFormatter()
        // Consistent format across all time ranges: "MMM d" (e.g., "Jan 3")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var dailyPatternsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Daily Patterns")
                    .font(.title2)
                    .fontWeight(.bold)
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
                .chartXScale(domain: 0...23)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(hourAxisLabel(for: hour))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            } else {
                EmptyChartView(message: "No hourly data available")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    private func hourAxisLabel(for hour: Int) -> String {
        switch hour {
        case 0: return "12am"
        case 6: return "6am"
        case 12: return "12pm"
        case 18: return "6pm"
        default: return "\(hour)"
        }
    }
    
    private var qualityDistributionSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Quality Distribution")
                    .font(.title2)
                    .fontWeight(.bold)
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
    
    private var aiInsightsSection: some View {
        AIInsightsSection(
            dailyInsight: viewModel.dailyInsight,
            weeklyInsight: viewModel.weeklyInsight,
            customInsight: viewModel.customInsight,
            canAskAI: viewModel.canAskAI,
            isLoadingAI: viewModel.isLoadingAIInsights,
            legacyHealthInsights: viewModel.healthInsights,
            isLoadingLegacy: viewModel.isLoadingInsights,
            activeDays: viewModel.activeDays,
            onAskAITapped: { isAskAISheetPresented = true }
        )
    }

    private var medicalDisclaimerSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("This app provides general wellness tracking only. Normal urination is 6-8 times daily. Consult a healthcare provider for medical advice.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(8)
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

// MARK: - Average Daily Card with Time Picker and Sparse Data Handling
struct AverageDailyCard: View {
    let value: Double
    let activeDays: Int
    @Binding var period: TimePeriod
    let isLoading: Bool
    let onCustomRangeTap: () -> Void

    private let minActiveDays = 3

    private var hasEnoughData: Bool {
        activeDays >= minActiveDays
    }

    private var color: Color {
        hasEnoughData ? .orange : .gray
    }

    private var displayValue: String {
        guard hasEnoughData else { return "--" }
        return String(format: "%.1f", value)
    }

    private var subtitle: String {
        guard hasEnoughData else { return "Log more days for average" }
        return "Based on \(activeDays) days"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()

                Menu {
                    Button("Last 7 Days") { period = .week }
                    Button("Last 30 Days") { period = .month }
                    Button("Last 90 Days") { period = .quarter }
                    Button("All Time") { period = .allTime }
                    Button("Custom Range") {
                        period = .custom
                        onCustomRangeTap()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(period.shortLabel)
                            .font(.caption2)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray5))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if isLoading {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 24)
                        .shimmering()
                } else {
                    Text(displayValue)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(hasEnoughData ? .primary : .secondary)
                }

                Text("Average Daily")
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

// MARK: - Health Score Card with Sparse Data Handling
struct HealthScoreCard: View {
    let healthScore: Double
    let activeDays: Int
    let interpretation: String
    let isLoading: Bool

    private let minActiveDays = 3

    private var hasEnoughData: Bool {
        activeDays >= minActiveDays
    }

    private var color: Color {
        guard hasEnoughData else { return .gray }
        if healthScore > 0.7 { return .green }
        if healthScore > 0.4 { return .orange }
        return .red
    }

    private var displayValue: String {
        guard hasEnoughData else { return "--" }
        return "\(Int(healthScore * 100))%"
    }

    private var subtitle: String {
        guard hasEnoughData else { return "Log more days for score" }
        return "Based on \(activeDays) days"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
                if hasEnoughData && !interpretation.isEmpty {
                    Text(interpretation)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(color)
                        .padding(.top, 2)
                }
                
            }

            VStack(alignment: .leading, spacing: 4) {
                if isLoading {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 24)
                        .shimmering()
                } else {
                    Text(displayValue)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(hasEnoughData ? .primary : .secondary)
                }

                Text("Health Score")
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
