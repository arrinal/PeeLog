//
//  ExportDataUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 17/01/26.
//

import Foundation

@MainActor
protocol ExportDataUseCaseProtocol {
    func exportToCSV() async throws -> URL
}

@MainActor
final class ExportDataUseCase: ExportDataUseCaseProtocol {
    private let peeEventRepository: PeeEventRepository
    
    init(peeEventRepository: PeeEventRepository) {
        self.peeEventRepository = peeEventRepository
    }
    
    func exportToCSV() async throws -> URL {
        let events = try peeEventRepository.fetchAllEvents()
        
        // Sort by timestamp (oldest first)
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        
        var csvContent = "Date,Time,Quality,Hydration Status,Notes,Location\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        for event in sortedEvents {
            let date = dateFormatter.string(from: event.timestamp)
            let time = timeFormatter.string(from: event.timestamp)
            let quality = escapeCSV(event.quality.rawValue)
            let status = escapeCSV(event.quality.description)
            let notes = escapeCSV(event.notes ?? "")
            let location = escapeCSV(event.locationName ?? "")
            
            csvContent += "\(date),\(time),\(quality),\(status),\(notes),\(location)\n"
        }
        
        let fileName = "PeeLog_Export_\(dateFormatter.string(from: Date())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
