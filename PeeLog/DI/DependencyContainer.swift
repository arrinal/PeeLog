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
class DependencyContainer: ObservableObject {
    private let modelContext: ModelContext
    private let locationService: LocationService
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.locationService = LocationService()
    }
    
    // Repositories
    private lazy var peeEventRepository: PeeEventRepository = {
        PeeEventRepositoryImpl(modelContext: modelContext)
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
struct DependencyContainerKey: EnvironmentKey {
    static var defaultValue: DependencyContainer {
        // Using @MainActor to safely access mainContext
        let container: ModelContainer
        do {
            container = try ModelContainer(for: PeeEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        
        // Create a new model context to avoid actor isolation issues
        let context = ModelContext(container)
        return DependencyContainer(modelContext: context)
    }
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
} 
