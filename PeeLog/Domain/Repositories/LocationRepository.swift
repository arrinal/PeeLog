//
//  LocationRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import CoreLocation
import Combine

// MARK: - Location Domain Models
struct LocationData: Equatable {
    let coordinate: CLLocationCoordinate2D
    let altitude: Double
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    let timestamp: Date
    let speed: Double
    let course: Double
    
    static func == (lhs: LocationData, rhs: LocationData) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.altitude == rhs.altitude &&
               lhs.horizontalAccuracy == rhs.horizontalAccuracy &&
               lhs.verticalAccuracy == rhs.verticalAccuracy &&
               lhs.timestamp == rhs.timestamp &&
               lhs.speed == rhs.speed &&
               lhs.course == rhs.course
    }
}

struct LocationInfo: Equatable {
    let data: LocationData
    let name: String?
    let address: String?
    
    static func == (lhs: LocationInfo, rhs: LocationInfo) -> Bool {
        return lhs.data.coordinate.latitude == rhs.data.coordinate.latitude &&
               lhs.data.coordinate.longitude == rhs.data.coordinate.longitude &&
               lhs.name == rhs.name &&
               lhs.address == rhs.address
    }
}

enum LocationError: Error, LocalizedError, Equatable {
    case permissionDenied
    case permissionNotDetermined
    case permissionRestricted
    case locationUnavailable
    case geocodingFailed(String)
    case timeout
    case serviceUnavailable
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied. Please enable location services in Settings."
        case .permissionNotDetermined:
            return "Location permission not determined. Please allow location access."
        case .permissionRestricted:
            return "Location access is restricted on this device."
        case .locationUnavailable:
            return "Current location is unavailable. Please try again."
        case .geocodingFailed(let message):
            return "Failed to get location name: \(message)"
        case .timeout:
            return "Location request timed out. Please try again."
        case .serviceUnavailable:
            return "Location services are not available."
        case .networkError:
            return "Network error occurred while getting location information."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied, .permissionRestricted:
            return "Go to Settings > Privacy & Security > Location Services to enable location access for this app."
        case .permissionNotDetermined:
            return "Allow location access when prompted."
        case .locationUnavailable, .timeout:
            return "Try moving to an area with better GPS signal or try again later."
        case .geocodingFailed, .networkError:
            return "Check your internet connection and try again."
        case .serviceUnavailable:
            return "Location services may be disabled. Check your device settings."
        }
    }
    
    // Equatable conformance
    static func == (lhs: LocationError, rhs: LocationError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.permissionNotDetermined, .permissionNotDetermined),
             (.permissionRestricted, .permissionRestricted),
             (.locationUnavailable, .locationUnavailable),
             (.timeout, .timeout),
             (.serviceUnavailable, .serviceUnavailable),
             (.networkError, .networkError):
            return true
        case (.geocodingFailed(let lhsMessage), .geocodingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

enum LocationAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorizedWhenInUse
    case authorizedAlways
    case unknown
    
    var isAuthorized: Bool {
        return self == .authorizedWhenInUse || self == .authorizedAlways
    }
}

// MARK: - Location Repository Protocol
@MainActor
protocol LocationRepository: AnyObject {
    // Published properties for observing
    var currentLocation: AnyPublisher<LocationInfo?, Never> { get }
    var authorizationStatus: AnyPublisher<LocationAuthorizationStatus, Never> { get }
    var isLoadingLocation: AnyPublisher<Bool, Never> { get }
    var lastError: AnyPublisher<LocationError?, Never> { get }
    
    // Core methods
    func requestPermission() async throws
    func getCurrentLocation() async throws -> LocationInfo
    func startLocationUpdates() async throws
    func stopLocationUpdates()
    
    // Utility methods
    func reverseGeocode(_ location: LocationData) async throws -> LocationInfo
    func isLocationServicesEnabled() -> Bool
} 