//
//  PeeEvent.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import Foundation
import SwiftData
import SwiftUI
import CoreLocation

// Enum for pee quality
enum PeeQuality: String, Codable, CaseIterable {
    case clear = "Clear"
    case paleYellow = "Pale Yellow"
    case yellow = "Yellow"
    case darkYellow = "Dark Yellow"
    case amber = "Amber"
    
    var description: String {
        switch self {
        case .clear: 
            return "Well hydrated"
        case .paleYellow: 
            return "Normal hydration"
        case .yellow: 
            return "Might need water soon"
        case .darkYellow: 
            return "Dehydration warning"
        case .amber: 
            return "Dehydrated - drink water!"
        }
    }
    
    var color: Color {
        switch self {
        case .clear: return Color(red: 0.9, green: 0.98, blue: 1.0) // Almost clear/white
        case .paleYellow: return Color(red: 0.98, green: 0.98, blue: 0.7) // Pale yellow
        case .yellow: return Color(red: 1.0, green: 0.9, blue: 0.4) // Medium yellow
        case .darkYellow: return Color(red: 0.9, green: 0.7, blue: 0.2) // Dark yellow
        case .amber: return Color(red: 0.85, green: 0.5, blue: 0.1) // Amber
        }
    }
    
    var emoji: String {
        switch self {
        case .clear: return "💧"
        case .paleYellow: return "🌟"
        case .yellow: return "⚠️"
        case .darkYellow: return "🚨"
        case .amber: return "🔴"
        }
    }
}

@Model
class PeeEvent {
    var id: UUID
    var timestamp: Date
    var notes: String?
    var quality: PeeQuality
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    
    init(timestamp: Date, notes: String? = nil, quality: PeeQuality = .paleYellow, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.notes = notes
        self.quality = quality
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
    
    var hasLocation: Bool {
        return latitude != nil && longitude != nil
    }
    
    var locationCoordinate: CLLocationCoordinate2D? {
        guard let latitude = latitude, let longitude = longitude else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
