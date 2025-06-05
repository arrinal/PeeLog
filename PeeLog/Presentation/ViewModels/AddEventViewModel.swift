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
    private let locationService: LocationService
    
    @Published var date = Date()
    @Published var time = Date()
    @Published var notes = ""
    @Published var selectedQuality: PeeQuality = .paleYellow
    @Published var includeLocation = false
    
    // Published properties that mirror the location service
    @Published var isLoadingLocation = false
    @Published var lastError: String?
    @Published var locationName: String?
    @Published var location: CLLocation?
    
    init(addPeeEventUseCase: AddPeeEventUseCase, locationService: LocationService) {
        self.addPeeEventUseCase = addPeeEventUseCase
        self.locationService = locationService
        
        // Set up observation of location service changes using Combine
        locationService.$isLoadingLocation
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoadingLocation)
            
        locationService.$lastError
            .receive(on: DispatchQueue.main)
            .assign(to: &$lastError)
            
        locationService.$locationName
            .receive(on: DispatchQueue.main)
            .assign(to: &$locationName)
            
        locationService.$location
            .receive(on: DispatchQueue.main)
            .assign(to: &$location)
    }
    
    private func updateLocationProperties() {
        isLoadingLocation = locationService.isLoadingLocation
        lastError = locationService.lastError
        locationName = locationService.locationName
        location = locationService.location
    }
    
    var isFutureDate: Bool {
        Calendar.current.isDateInToday(date) || Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    func isFutureCombinedDateTime() -> Bool {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        let combinedDateTime = calendar.date(from: combinedComponents) ?? Date()
        
        return combinedDateTime > Date()
    }
    
    func saveEvent(context: ModelContext) {
        // Combine date and time components
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        var combinedTimestamp = calendar.date(from: combinedComponents) ?? Date()
        
        // Extra validation to ensure we're not in the future
        if combinedTimestamp > Date() {
            combinedTimestamp = Date()
        }
        
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Create event with location if available and requested
        let newEvent: PeeEvent
        if includeLocation, let location = locationService.location {
            newEvent = PeeEvent(
                timestamp: combinedTimestamp,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                quality: selectedQuality,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                locationName: locationService.locationName
            )
        } else {
            newEvent = PeeEvent(
                timestamp: combinedTimestamp,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                quality: selectedQuality
            )
        }
        
        addPeeEventUseCase.execute(event: newEvent, context: context)
    }
    
    func requestLocationPermission() {
        locationService.requestPermission()
    }
    
    func startUpdatingLocation() {
        locationService.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationService.stopUpdatingLocation()
    }
} 