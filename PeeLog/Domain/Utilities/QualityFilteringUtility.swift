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
    
    /// Returns events with overhydrated quality (clear)
    static func getOverhydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .clear }
    }
    
    /// Returns events with mildly dehydrated quality (yellow)
    static func getMildlyDehydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .yellow }
    }
    
    /// Returns events with dehydrated quality (dark yellow)
    static func getDehydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .darkYellow }
    }
    
    /// Returns events with severely dehydrated quality (amber)
    static func getSeverelyDehydratedEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .amber }
    }
    
    // MARK: - Quality Category Counts
    
    /// Returns count of events with optimal hydration quality
    static func getOptimalCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .paleYellow }.count
    }
    
    /// Returns count of events with overhydrated quality
    static func getOverhydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .clear }.count
    }
    
    /// Returns count of events with mildly dehydrated quality
    static func getMildlyDehydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .yellow }.count
    }
    
    /// Returns count of events with dehydrated quality
    static func getDehydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .darkYellow }.count
    }
    
    /// Returns count of events with severely dehydrated quality
    static func getSeverelyDehydratedCount(from events: [PeeEvent]) -> Int {
        return events.filter { $0.quality == .amber }.count
    }
    
    // MARK: - Quality Group Filtering
    
    /// Returns events with acceptable hydration quality (clear or pale yellow)
    static func getAcceptableEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .clear || $0.quality == .paleYellow }
    }
    
    /// Returns events with concerning hydration quality (yellow, dark yellow, or amber)
    static func getConcerningEvents(from events: [PeeEvent]) -> [PeeEvent] {
        return events.filter { $0.quality == .yellow || $0.quality == .darkYellow || $0.quality == .amber }
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
            overhydratedCount: getOverhydratedCount(from: events),
            mildlyDehydratedCount: getMildlyDehydratedCount(from: events),
            dehydratedCount: getDehydratedCount(from: events),
            severelyDehydratedCount: getSeverelyDehydratedCount(from: events)
        )
    }
}

// MARK: - Quality Distribution Summary
struct QualityDistributionSummary {
    let optimalCount: Int
    let overhydratedCount: Int
    let mildlyDehydratedCount: Int
    let dehydratedCount: Int
    let severelyDehydratedCount: Int
    
    var totalCount: Int {
        return optimalCount + overhydratedCount + mildlyDehydratedCount + dehydratedCount + severelyDehydratedCount
    }
    
    var healthScore: Double {
        guard totalCount > 0 else { return 0.0 }
        
        // Calculate health score based on distribution
        let optimalScore = Double(optimalCount) / Double(totalCount) * 1.0
        let acceptableScore = Double(overhydratedCount) / Double(totalCount) * 0.7
        let concerningScore = Double(mildlyDehydratedCount + dehydratedCount + severelyDehydratedCount) / Double(totalCount) * 0.3
        
        return optimalScore + acceptableScore + concerningScore
    }
} 