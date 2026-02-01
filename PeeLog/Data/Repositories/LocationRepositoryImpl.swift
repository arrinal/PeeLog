//
//  LocationRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import CoreLocation
@preconcurrency import Combine

@MainActor
class LocationRepositoryImpl: LocationRepository {
    private let locationService: LocationService
    private var cancellables = Set<AnyCancellable>()
    
    // Subjects for publishing
    private let currentLocationSubject = CurrentValueSubject<LocationInfo?, Never>(nil)
    private let authorizationStatusSubject = CurrentValueSubject<LocationAuthorizationStatus, Never>(.notDetermined)
    private let isLoadingLocationSubject = CurrentValueSubject<Bool, Never>(false)
    private let lastErrorSubject = CurrentValueSubject<LocationError?, Never>(nil)
    
    init(locationService: LocationService) {
        self.locationService = locationService
        setupObservers()
    }
    
    // MARK: - Published Properties
    var currentLocation: AnyPublisher<LocationInfo?, Never> {
        currentLocationSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatus: AnyPublisher<LocationAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    var isLoadingLocation: AnyPublisher<Bool, Never> {
        isLoadingLocationSubject.eraseToAnyPublisher()
    }
    
    var lastError: AnyPublisher<LocationError?, Never> {
        lastErrorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Setup Observers
    private func setupObservers() {
        // Observe both location and location name updates
        locationService.$location
            .combineLatest(locationService.$locationName)
            .compactMap { [weak self] location, locationName in
                guard let location = location else { return nil }
                return self?.mapCLLocationToLocationInfo(location, name: locationName)
            }
            .removeDuplicates { oldInfo, newInfo in
                // Only emit if coordinate changed significantly or name changed
                guard let oldInfo = oldInfo, let newInfo = newInfo else { return false }
                
                let latDiff = abs(oldInfo.data.coordinate.latitude - newInfo.data.coordinate.latitude)
                let lonDiff = abs(oldInfo.data.coordinate.longitude - newInfo.data.coordinate.longitude)
                let coordinateThreshold = 0.0001 // ~11 meters
                
                let coordinatesEqual = latDiff < coordinateThreshold && lonDiff < coordinateThreshold
                let namesEqual = oldInfo.name == newInfo.name
                
                return coordinatesEqual && namesEqual
            }
            .assign(to: \.value, on: currentLocationSubject)
            .store(in: &cancellables)
        
        // Observe authorization status
        locationService.$authorizationStatus
            .map(mapCLAuthorizationStatus)
            .assign(to: \.value, on: authorizationStatusSubject)
            .store(in: &cancellables)
        
        // Observe loading state
        locationService.$isLoadingLocation
            .assign(to: \.value, on: isLoadingLocationSubject)
            .store(in: &cancellables)
        
        // Observe errors
        locationService.$lastError
            .map { errorString in
                guard let errorString = errorString else { return nil }
                return LocationError.geocodingFailed(errorString)
            }
            .assign(to: \.value, on: lastErrorSubject)
            .store(in: &cancellables)
    }
    
    // MARK: - Core Methods
    func requestPermission() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            // Clear any previous errors
            lastErrorSubject.value = nil
            
            // Request permission
            locationService.requestPermission()
            
            // Wait for authorization status change
            authorizationStatus
                .dropFirst() // Skip current value
                .first()
                .sink { status in
                    switch status {
                    case .authorizedWhenInUse, .authorizedAlways:
                        continuation.resume()
                    case .denied:
                        continuation.resume(throwing: LocationError.permissionDenied)
                    case .restricted:
                        continuation.resume(throwing: LocationError.permissionRestricted)
                    case .notDetermined:
                        continuation.resume(throwing: LocationError.permissionNotDetermined)
                    case .unknown:
                        continuation.resume(throwing: LocationError.serviceUnavailable)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    func getCurrentLocation() async throws -> LocationInfo {
        // Clear any previous errors
        lastErrorSubject.value = nil
        
        // Check if we have permission
        if !authorizationStatusSubject.value.isAuthorized {
            if authorizationStatusSubject.value == .notDetermined {
                throw LocationError.permissionNotDetermined
            }
            throw LocationError.permissionDenied
        }
        
        // Check if location services are enabled
        guard isLocationServicesEnabled() else {
            throw LocationError.serviceUnavailable
        }
        
        // Start location updates if not already running
        try await startLocationUpdates()
        
        // Wait for location with timeout
        return try await withTimeout(seconds: 10) {
            try await withCheckedThrowingContinuation { [weak self] continuation in
                guard let self = self else {
                    continuation.resume(throwing: LocationError.serviceUnavailable)
                    return
                }
                
                var resumed = false
                var cancellable: AnyCancellable?
                
                Task { @MainActor in
                    cancellable = self.currentLocation
                        .compactMap { $0 }
                        .first()
                        .sink { location in
                            guard !resumed else { return }
                            resumed = true
                            cancellable?.cancel()
                            continuation.resume(returning: location)
                        }
                    
                    // Also handle errors
                    let errorCancellable = self.lastError
                        .compactMap { $0 }
                        .first()
                        .sink { error in
                            guard !resumed else { return }
                            resumed = true
                            cancellable?.cancel()
                            continuation.resume(throwing: error)
                        }
                    
                    // Store cancellables safely
                    if let cancellable = cancellable {
                        self.cancellables.insert(cancellable)
                    }
                    self.cancellables.insert(errorCancellable)
                }

            }
        }
    }
    
    func startLocationUpdates() async throws {
        guard authorizationStatusSubject.value.isAuthorized else {
            throw LocationError.permissionDenied
        }
        
        guard isLocationServicesEnabled() else {
            throw LocationError.serviceUnavailable
        }
        
        locationService.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationService.stopUpdatingLocation()
    }
    
    // MARK: - Utility Methods
    func reverseGeocode(_ location: LocationData) async throws -> LocationInfo {
        let clLocation = CLLocation(
            coordinate: location.coordinate,
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            verticalAccuracy: location.verticalAccuracy,
            timestamp: location.timestamp
        )
        
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(clLocation)
            guard let placemark = placemarks.first else {
                return LocationInfo(data: location, name: nil, address: nil)
            }
            
            let name = buildLocationName(from: placemark)
            let address = buildAddress(from: placemark)
            
            return LocationInfo(data: location, name: name, address: address)
        } catch {
            throw LocationError.geocodingFailed(error.localizedDescription)
        }
    }
    
    func isLocationServicesEnabled() -> Bool {
        return CLLocationManager.locationServicesEnabled()
    }
    
    // MARK: - Helper Methods
    private func mapCLLocationToLocationInfo(_ clLocation: CLLocation, name: String?) -> LocationInfo {
        let locationData = LocationData(
            coordinate: clLocation.coordinate,
            altitude: clLocation.altitude,
            horizontalAccuracy: clLocation.horizontalAccuracy,
            verticalAccuracy: clLocation.verticalAccuracy,
            timestamp: clLocation.timestamp,
            speed: clLocation.speed,
            course: clLocation.course
        )
        
        return LocationInfo(data: locationData, name: name, address: nil)
    }
    
    private func mapCLAuthorizationStatus(_ clStatus: CLAuthorizationStatus) -> LocationAuthorizationStatus {
        switch clStatus {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .unknown
        }
    }
    
    private func buildLocationName(from placemark: CLPlacemark) -> String? {
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
        
        return name.isEmpty ? nil : name
    }
    
    private func buildAddress(from placemark: CLPlacemark) -> String? {
        var addressComponents: [String] = []
        
        if let subThoroughfare = placemark.subThoroughfare {
            addressComponents.append(subThoroughfare)
        }
        
        if let thoroughfare = placemark.thoroughfare {
            addressComponents.append(thoroughfare)
        }
        
        if let locality = placemark.locality {
            addressComponents.append(locality)
        }
        
        if let administrativeArea = placemark.administrativeArea {
            addressComponents.append(administrativeArea)
        }
        
        if let postalCode = placemark.postalCode {
            addressComponents.append(postalCode)
        }
        
        return addressComponents.isEmpty ? nil : addressComponents.joined(separator: ", ")
    }
    
    // Timeout helper
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                return try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw LocationError.timeout
            }
            
            guard let result = try await group.next() else {
                throw LocationError.timeout
            }
            
            group.cancelAll()
            return result
        }
    }
} 