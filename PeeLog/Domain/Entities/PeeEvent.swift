//
//  PeeEvent.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData
import CoreLocation

@Model
final class PeeEvent {
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