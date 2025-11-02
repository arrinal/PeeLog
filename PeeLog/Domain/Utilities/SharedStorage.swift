//
//  SharedStorage.swift
//  PeeLog
//
//  Created by Arrinal S on 08/10/25.
//

import Foundation
import CoreLocation

// Simple shared storage bridge for widget/intents communication via App Group UserDefaults
enum SharedStorage {
    static let appGroupId = "group.com.arrinal.PeeLog"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }

    enum Keys {
        static let lastKnownLatitude = "lastKnownLatitude"
        static let lastKnownLongitude = "lastKnownLongitude"
        static let lastKnownLocationName = "lastKnownLocationName"
        static let lastUpdatedAt = "lastLocationUpdatedAt"
    }

    static func save(location: CLLocation?, name: String?) {
        guard let defaults else { return }
        if let loc = location {
            defaults.set(loc.coordinate.latitude, forKey: Keys.lastKnownLatitude)
            defaults.set(loc.coordinate.longitude, forKey: Keys.lastKnownLongitude)
        }
        if let name { defaults.set(name, forKey: Keys.lastKnownLocationName) }
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastUpdatedAt)
    }

    static func readLocation() -> (coordinate: CLLocationCoordinate2D?, name: String?) {
        guard let defaults else { return (nil, nil) }
        let lat = defaults.double(forKey: Keys.lastKnownLatitude)
        let lon = defaults.double(forKey: Keys.lastKnownLongitude)
        let hasLat = defaults.object(forKey: Keys.lastKnownLatitude) != nil
        let hasLon = defaults.object(forKey: Keys.lastKnownLongitude) != nil
        let coord: CLLocationCoordinate2D? = (hasLat && hasLon) ? CLLocationCoordinate2D(latitude: lat, longitude: lon) : nil
        let name = defaults.string(forKey: Keys.lastKnownLocationName)
        return (coord, name)
    }
}




