//
//  QualityFilteringUtility.swift
//  PeeLog
//
//  Created by Arrinal S on 25/06/25.
//

import Foundation

// MARK: - Quality Filtering Utility
struct QualityFilteringUtility {
    
    // MARK: - Quality Category Filtering
    
    /// Returns events with optimal hydration quality (pale yellow)
    static func getOptimalEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .paleYellow }
    }
    
    /// Returns events with well-hydrated quality (clear)
    static func getWellHydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .clear }
    }
    
    /// Returns events with normal hydration quality (yellow)
    static func getNormalEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .yellow }
    }
    
    /// Returns events with mildly dehydrated quality (dark yellow)
    static func getMildlyDehydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .darkYellow }
    }
    
    /// Returns events with dehydrated quality (amber)
    static func getDehydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .amber }
    }
    
    // MARK: - Quality Category Counts
    
    /// Returns count of events with optimal hydration quality
    static func getOptimalCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .paleYellow }.count
    }
    
    /// Returns count of events with well-hydrated quality
    static func getWellHydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .clear }.count
    }
    
    /// Returns count of events with normal hydration quality
    static func getNormalCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .yellow }.count
    }
    
    /// Returns count of events with mildly dehydrated quality
    static func getMildlyDehydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .darkYellow }.count
    }
    
    /// Returns count of events with dehydrated quality
    static func getDehydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .amber }.count
    }
    
    // MARK: - Quality Group Filtering
    
    /// Returns events with acceptable hydration quality (clear, pale yellow, or yellow)
    static func getAcceptableEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .clear || $0.quality == .paleYellow || $0.quality == .yellow }
    }
    
    /// Returns events with concerning hydration quality (dark yellow or amber)
    static func getConcerningEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .darkYellow || $0.quality == .amber }
    }
    
    // MARK: - Quality Distribution
    
    /// Returns a dictionary with quality distribution counts
    static func getQualityDistribution(from events: [PeeEvent]) -> [PeeQuality: Int] {
        var distribution: [PeeQuality: Int] = [:]
        
        for quality in PeeQuality.allCases {
            distribution[quality] = events.filter { $0.quality == quality }.count
        }
        
        return distribution
    }
    
    /// Returns quality distribution as a structured result
    static func getQualityDistributionSummary(from events: [PeeEvent]) -> QualityDistributionSummary {
        return QualityDistributionSummary(
            optimalCount: getOptimalCount(from: events),
            wellHydratedCount: getWellHydratedCount(from: events),
            normalCount: getNormalCount(from: events),
            mildlyDehydratedCount: getMildlyDehydratedCount(from: events),
            dehydratedCount: getDehydratedCount(from: events)
        )
    }
}

// MARK: - Quality Distribution Summary
struct QualityDistributionSummary {
    let optimalCount: Int
    let wellHydratedCount: Int
    let normalCount: Int
    let mildlyDehydratedCount: Int
    let dehydratedCount: Int
    
    var totalCount: Int {
        return optimalCount + wellHydratedCount + normalCount + mildlyDehydratedCount + dehydratedCount
    }
    
    var healthScore: Double {
        guard totalCount > 0 else { return 0.0 }
        
        // Calculate health score based on distribution
        let optimalScore = Double(optimalCount) / Double(totalCount) * 1.0
        let acceptableScore = Double(wellHydratedCount + normalCount) / Double(totalCount) * 0.7
        let concerningScore = Double(mildlyDehydratedCount + dehydratedCount) / Double(totalCount) * 0.3
        
        return optimalScore + acceptableScore + concerningScore
    }
} 