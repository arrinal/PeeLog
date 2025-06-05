//
//  DependencyContainer.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData
import SwiftUI

// Dependency Container class that holds all dependencies
@MainActor
class DependencyContainer: ObservableObject {
    private let locationService: LocationService
    
    init() {
        self.locationService = LocationService()
    }
    
    // Repositories
    private lazy var peeEventRepository: PeeEventRepository = {
        PeeEventRepositoryImpl()
    }()
    
    // Use cases
    private lazy var getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase = {
        GetTodaysPeeEventsUseCase(repository: peeEventRepository)
    }()
    
    private lazy var getPeeEventsWithLocationUseCase: GetPeeEventsWithLocationUseCase = {
        GetPeeEventsWithLocationUseCase(repository: peeEventRepository)
    }()
    
    private lazy var addPeeEventUseCase: AddPeeEventUseCase = {
        AddPeeEventUseCase(repository: peeEventRepository)
    }()
    
    private lazy var deletePeeEventUseCase: DeletePeeEventUseCase = {
        DeletePeeEventUseCase(repository: peeEventRepository)
    }()
    
    // View models
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getTodaysPeeEventsUseCase: getTodaysPeeEventsUseCase,
            deleteEventUseCase: deletePeeEventUseCase
        )
    }
    
    func makeMapHistoryViewModel() -> MapHistoryViewModel {
        MapHistoryViewModel(
            getPeeEventsWithLocationUseCase: getPeeEventsWithLocationUseCase
        )
    }
    
    func makeAddEventViewModel() -> AddEventViewModel {
        AddEventViewModel(
            addPeeEventUseCase: addPeeEventUseCase,
            locationService: locationService
        )
    }
}

// Environment key for the dependency container
struct DependencyContainerKey: @preconcurrency EnvironmentKey {
    @MainActor static var defaultValue: DependencyContainer {
        return DependencyContainer()
    }
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
} 
