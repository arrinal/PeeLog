//
//  GenerateQualityDistributionUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 14/06/25.
//

import Foundation

// Use case for generating quality distribution
class GenerateQualityDistributionUseCase {
    private let repository: PeeEventRepository
    
    init(repository: PeeEventRepository) {
        self.repository = repository
    }
    
    func execute(events: [PeeEvent]) -> [QualityDistribution] {
        let groupedByQuality = Dictionary(grouping: events) { $0.quality }
        
        return PeeQuality.allCases.compactMap { quality in
            let count = groupedByQuality[quality]?.count ?? 0
            return count > 0 ? QualityDistribution(quality: quality, count: count) : nil
        }.sorted { $0.count > $1.count }
    }
}

// Data structure for quality distribution
struct QualityDistribution: Identifiable {
    let id = UUID()
    let quality: PeeQuality
    let count: Int
} 