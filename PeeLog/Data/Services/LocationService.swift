//
//  LocationService.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    // Rate limiting values
    private let minTimeBetweenGeocodingRequests: TimeInterval = 2 // At least 2 seconds between requests
    private let significantDistanceChange: CLLocationDistance = 50 // 50 meters is significant
    private let loadingTimeoutInterval: TimeInterval = 2 // 2 seconds max loading time
    
    // Private tracking properties
    private var lastGeocodedLocation: CLLocation?
    private var lastGeocodingTime: Date?
    private var loadingTimeoutWorkItem: DispatchWorkItem?
    
    // Published properties
    @Published var location: CLLocation?
    @Published var locationName: String?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var isLoadingLocation = false
    @Published var lastError: String?
    @Published var debugMessage: String = ""
    
    override init() {
        authorizationStatus = locationManager.authorizationStatus
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10 // Only update when moved at least 10 meters
        
        // Print current authorization status
        let status = locationManager.authorizationStatus
        debugMessage = "Initial status: \(statusToString(status))"
    }
    
    private func statusToString(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
    
    func requestPermission() {
        // Check if permission has already been determined
        let currentStatus = locationManager.authorizationStatus
        debugMessage = "Requesting permission. Current status: \(statusToString(currentStatus))"
        
        // If permission is not determined yet, request it
        if currentStatus == .notDetermined {
            // Only request when in use permission for simplicity
            locationManager.requestWhenInUseAuthorization()
            debugMessage += "\nSent requestWhenInUseAuthorization"
        } else if currentStatus == .denied || currentStatus == .restricted {
            // If denied, suggest going to settings
            debugMessage += "\nPermission was previously denied. Please go to Settings to enable location."
            lastError = "Location permission denied. Please go to Settings > Privacy > Location Services to enable location for this app."
        } else {
            // Already authorized, start updating
            debugMessage += "\nAlready authorized: \(statusToString(currentStatus))"
            startUpdatingLocation()
        }
    }
    
    func startUpdatingLocation() {
        isLoadingLocation = true
        lastError = nil
        
        // Cancel any previous loading timeout
        loadingTimeoutWorkItem?.cancel()
        
        // Set a timeout to ensure loading state doesn't get stuck
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                
                // If we're still loading after timeout, reset state and set a fallback location name
                if self.isLoadingLocation {
                    self.isLoadingLocation = false
                    if self.locationName == nil && self.location != nil {
                        self.locationName = "Location found"
                    }
                    self.debugMessage += "\nLocation loading timed out, resetting state"
                }
            }
        }
        
        // Set the new timeout
        self.loadingTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingTimeoutInterval, execute: timeoutWorkItem)
        
        // Start location updates
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isLoadingLocation = false
        loadingTimeoutWorkItem?.cancel()
        loadingTimeoutWorkItem = nil
        
        // Cancel any pending geocoding requests
        geocoder.cancelGeocode()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            debugMessage += "\nAuthorization changed: \(statusToString(manager.authorizationStatus))"
            
            #if os(macOS)
            let isAuthorized = manager.authorizationStatus == .authorized
            #else
            let isAuthorized = manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways
            #endif
            
            if isAuthorized {
                debugMessage += "\nAuthorized, starting location updates"
                startUpdatingLocation()
            } else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
                debugMessage += "\nPermission denied or restricted"
                lastError = "Location access denied. Please enable location services for this app in Settings."
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            guard let newLocation = locations.last else { return }
            
            // Always update the user location
            location = newLocation
            
            // Check if we should perform geocoding
            let shouldGeocode = shouldPerformGeocoding(for: newLocation)
            
            // If we should geocode, do it
            if shouldGeocode {
                reverseGeocode(location: newLocation)
            } else if !isLoadingLocation && locationName == nil {
                // If not geocoding but we have no location name, set a reasonable default
                locationName = "Current Location"
            }
        }
    }
    
    // Helper to determine if we should perform geocoding
    private func shouldPerformGeocoding(for newLocation: CLLocation) -> Bool {
        // If we've never geocoded, definitely do it
        guard let lastLocation = lastGeocodedLocation, let lastTime = lastGeocodingTime else {
            return true
        }
        
        // Check time since last geocoding request
        let timeSinceLastGeocode = Date().timeIntervalSince(lastTime)
        if timeSinceLastGeocode < minTimeBetweenGeocodingRequests {
            debugMessage += "\nSkipping geocode - too soon since last request"
            return false
        }
        
        // Check if location significantly changed
        let distanceChanged = newLocation.distance(from: lastLocation)
        if distanceChanged < significantDistanceChange {
            debugMessage += "\nSkipping geocode - location hasn't changed significantly"
            return false
        }
        
        // If we've passed all checks, perform geocoding
        return true
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isLoadingLocation = false
            lastError = error.localizedDescription
        }
    }
    
    private func reverseGeocode(location: CLLocation) {
        // Cancel any pending geocoding requests
        geocoder.cancelGeocode()
        
        // Update state
        isLoadingLocation = true
        lastGeocodedLocation = location
        lastGeocodingTime = Date()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    // Only update error if it's not a cancellation error
                    if (error as NSError).domain != kCLErrorDomain || (error as NSError).code != CLError.geocodeCanceled.rawValue {
                        self.lastError = error.localizedDescription
                        self.debugMessage += "\nGeocoding error: \(error.localizedDescription)"
                    }
                    self.isLoadingLocation = false
                    return
                }
                
                if let placemark = placemarks?.first {
                    // Create a meaningful location name
                    var name = ""
                    
                    if let thoroughfare = placemark.thoroughfare {
                        name += thoroughfare
                    }
                    
                    if let subThoroughfare = placemark.subThoroughfare {
                        if !name.isEmpty {
                            name += " "
                        }
                        name += subThoroughfare
                    }
                    
                    if name.isEmpty, let locality = placemark.locality {
                        name = locality
                    }
                    
                    if name.isEmpty, let areaOfInterest = placemark.areasOfInterest?.first {
                        name = areaOfInterest
                    }
                    
                    if !name.isEmpty {
                        self.locationName = name
                    } else {
                        self.locationName = "Unknown location"
                    }
                } else {
                    self.locationName = "Unknown location"
                }
                
                self.isLoadingLocation = false
            }
        }
    }
} 
