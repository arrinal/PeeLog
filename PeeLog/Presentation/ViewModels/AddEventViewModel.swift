//
//  AddEventViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI
import CoreLocation
import Combine
import SwiftData

@MainActor
class AddEventViewModel: ObservableObject {
    private let addPeeEventUseCase: AddPeeEventUseCase
    private let locationRepository: LocationRepository
    private let errorHandlingUseCase: ErrorHandlingUseCase
    private let syncCoordinator: SyncCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    @Published var date = Date()
    @Published var time = Date()
    @Published var notes = ""
    @Published var selectedQuality: PeeQuality = .paleYellow
    @Published var includeLocation = false
    
    // Location-related published properties
    @Published var isLoadingLocation = false
    @Published var lastError: String?
    @Published var locationName: String?
    @Published var currentLocationInfo: LocationInfo?
    @Published var authorizationStatus: LocationAuthorizationStatus = .notDetermined
    
    // Error handling
    @Published var showErrorAlert = false
    @Published var errorMessage = ""
    
    init(addPeeEventUseCase: AddPeeEventUseCase, locationRepository: LocationRepository, errorHandlingUseCase: ErrorHandlingUseCase, syncCoordinator: SyncCoordinator) {
        self.addPeeEventUseCase = addPeeEventUseCase
        self.locationRepository = locationRepository
        self.errorHandlingUseCase = errorHandlingUseCase
        self.syncCoordinator = syncCoordinator
        
        setupLocationObservers()
    }
    
    private func setupLocationObservers() {
        // Observe location updates
        locationRepository.currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locationInfo in
                self?.currentLocationInfo = locationInfo
                self?.locationName = locationInfo?.name
            }
            .store(in: &cancellables)
        
        // Observe authorization status
        locationRepository.authorizationStatus
            .receive(on: DispatchQueue.main)
            .assign(to: \.authorizationStatus, on: self)
            .store(in: &cancellables)
        
        // Observe loading state
        locationRepository.isLoadingLocation
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoadingLocation, on: self)
            .store(in: &cancellables)
        
        // Observe location errors
        locationRepository.lastError
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locationError in
                self?.handleLocationError(locationError)
            }
            .store(in: &cancellables)
    }
    
    private func handleLocationError(_ locationError: LocationError) {
        let context = ErrorContext(
            operation: "location_request",
            userAction: "user_requested_location",
            additionalInfo: ["error": locationError.localizedDescription]
        )
        
        let result = errorHandlingUseCase.handleError(locationError, context: context)
        
        if result.error.shouldShowToUser {
            lastError = result.userMessage
            errorMessage = result.userMessage
            showErrorAlert = true
        }
        
        if result.shouldLog {
            print("Location Error: \(result.error) - \(result.userMessage)")
        }
    }
    
    // MARK: - Computed Properties
    var isFutureDate: Bool {
        CalendarUtility.isDateInToday(date) || CalendarUtility.isDate(date, inSameDayAs: Date())
    }
    
    var canRequestLocation: Bool {
        return authorizationStatus != .denied && authorizationStatus != .restricted
    }
    
    var isLocationAuthorized: Bool {
        return authorizationStatus.isAuthorized
    }
    
    // MARK: - Date Validation
    func isFutureCombinedDateTime() -> Bool {
        let calendar = CalendarUtility.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second
        combinedComponents.nanosecond = timeComponents.nanosecond
        
        let combinedDateTime = calendar.date(from: combinedComponents) ?? Date()
        
        return combinedDateTime > Date()
    }
    
    // MARK: - Event Management
    func saveEvent() async {
        do {
            let event = try await createPeeEvent()
            try addPeeEventUseCase.execute(event: event)
            // Fire-and-forget cloud upsert for authenticated users
            Task { try? await syncCoordinator.syncUpsertSingleEvent(event) }
        } catch {
            await handleSaveError(error)
        }
    }
    
    private func createPeeEvent() async throws -> PeeEvent {
        // Combine date and time components with full precision
        let calendar = CalendarUtility.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        combinedComponents.second = timeComponents.second
        combinedComponents.nanosecond = timeComponents.nanosecond
        
        var combinedTimestamp = calendar.date(from: combinedComponents) ?? Date()
        
        // Extra validation to ensure we're not in the future
        if combinedTimestamp > Date() {
            combinedTimestamp = Date()
        }
        
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create event with location if available and requested
        if includeLocation, let locationInfo = currentLocationInfo {
            return PeeEvent(
                timestamp: combinedTimestamp,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                quality: selectedQuality,
                latitude: locationInfo.data.coordinate.latitude,
                longitude: locationInfo.data.coordinate.longitude,
                locationName: locationInfo.name
            )
        } else {
            return PeeEvent(
                timestamp: combinedTimestamp,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                quality: selectedQuality
            )
        }
    }
    
    private func handleSaveError(_ error: Error) async {
        let context = ErrorContext(
            operation: "save_event",
            userAction: "user_saving_event",
            additionalInfo: ["notes": notes, "quality": selectedQuality.rawValue]
        )
        
        let result = errorHandlingUseCase.handleError(error, context: context)
        
        if result.error.shouldShowToUser {
            errorMessage = result.userMessage
            showErrorAlert = true
        }
        
        if result.shouldLog {
            print("Save Error: \(result.error) - \(result.userMessage)")
        }
    }
    
    // MARK: - Location Management
    func requestLocationPermission() async {
        guard canRequestLocation else {
                    let context = ErrorContextHelper.createLocationPermissionContext()
            let error = AppError.permissionDenied("Location permission was previously denied")
            let result = errorHandlingUseCase.handleError(error, context: context)
            
            errorMessage = result.userMessage
            showErrorAlert = true
            return
        }
        
        do {
            try await locationRepository.requestPermission()
        } catch {
            // Error is already handled by the repository observer
        }
    }
    
    func startUpdatingLocation() async {
        guard isLocationAuthorized else {
            await requestLocationPermission()
            return
        }
        
        do {
            try await locationRepository.startLocationUpdates()
        } catch {
            // Error is already handled by the repository observer
        }
    }
    
    func stopUpdatingLocation() {
        locationRepository.stopLocationUpdates()
    }
    
    func getCurrentLocation() async {
        guard isLocationAuthorized else {
            await requestLocationPermission()
            return
        }
        
        do {
            let locationInfo = try await locationRepository.getCurrentLocation()
            currentLocationInfo = locationInfo
            locationName = locationInfo.name
        } catch {
            // Error is already handled by the repository observer
        }
    }
    
    // MARK: - Utility Methods
    func clearError() {
        lastError = nil
        errorMessage = ""
        showErrorAlert = false
    }
    
    func toggleLocationInclusion() {
        includeLocation.toggle()
        
        if includeLocation && currentLocationInfo == nil && isLocationAuthorized {
            Task {
                await getCurrentLocation()
            }
        }
    }
} 