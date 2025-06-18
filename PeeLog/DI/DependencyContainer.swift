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
    // MARK: - Core Services
    private let locationService: LocationService
    private let locationRepository: LocationRepository
    private let errorHandlingUseCase: ErrorHandlingUseCase
    
    // MARK: - Repository Cache
    private var peeEventRepository: PeeEventRepository?
    
    init() {
        // Initialize core services
        self.locationService = LocationService()
        self.locationRepository = LocationRepositoryImpl(locationService: locationService)
        self.errorHandlingUseCase = ErrorHandlingUseCaseImpl()
    }
    
    // MARK: - Repository Factory Methods
    private func getPeeEventRepository(modelContext: ModelContext) -> PeeEventRepository {
        if let repository = peeEventRepository {
            return repository
        }
        let repository = PeeEventRepositoryImpl(modelContext: modelContext)
        self.peeEventRepository = repository
        return repository
    }
    
    // MARK: - Location Repository Access
    func getLocationRepository() -> LocationRepository {
        return locationRepository
    }
    
    // MARK: - Error Handling Use Case Access
    func getErrorHandlingUseCase() -> ErrorHandlingUseCase {
        return errorHandlingUseCase
    }
    
    // MARK: - View Model Factory Methods
    func makeHomeViewModel(modelContext: ModelContext) -> HomeViewModel {
        let repository = getPeeEventRepository(modelContext: modelContext)
        return HomeViewModel(
            getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase(repository: repository),
            deleteEventUseCase: DeletePeeEventUseCase(repository: repository)
        )
    }
    
    func makeMapHistoryViewModel(modelContext: ModelContext) -> MapHistoryViewModel {
        let repository = getPeeEventRepository(modelContext: modelContext)
        return MapHistoryViewModel(
            getPeeEventsWithLocationUseCase: GetPeeEventsWithLocationUseCase(repository: repository)
        )
    }
    
    func makeAddEventViewModel(modelContext: ModelContext) -> AddEventViewModel {
        let repository = getPeeEventRepository(modelContext: modelContext)
        return AddEventViewModel(
            addPeeEventUseCase: AddPeeEventUseCase(repository: repository),
            locationRepository: locationRepository,
            errorHandlingUseCase: errorHandlingUseCase
        )
    }
    
    func makeStatisticsViewModel(modelContext: ModelContext) -> StatisticsViewModel {
        let repository = getPeeEventRepository(modelContext: modelContext)
        return StatisticsViewModel(
            getAllEventsUseCase: GetAllPeeEventsUseCase(repository: repository),
            calculateStatisticsUseCase: CalculateBasicStatisticsUseCase(repository: repository),
            generateQualityTrendsUseCase: GenerateQualityTrendsUseCase(repository: repository),
            generateHealthInsightsUseCase: GenerateHealthInsightsUseCase(repository: repository),
            analyzeHourlyPatternsUseCase: AnalyzeHourlyPatternsUseCase(repository: repository),
            generateQualityDistributionUseCase: GenerateQualityDistributionUseCase(repository: repository),
            generateWeeklyDataUseCase: GenerateWeeklyDataUseCase(repository: repository)
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
