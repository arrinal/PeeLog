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
    
    // MARK: - Firebase Services
    private let firebaseAuthService: FirebaseAuthService
    private let firestoreService: FirestoreService
    
    // MARK: - Repository Cache - keyed by ModelContext
    private var peeEventRepositories: [ObjectIdentifier: PeeEventRepository] = [:]
    private var authRepositories: [ObjectIdentifier: AuthRepository] = [:]
    private var userRepositories: [ObjectIdentifier: UserRepository] = [:]
    
    // MARK: - Shared Repository Instances
    private var sharedUserRepository: UserRepository?
    private var sharedAuthRepository: AuthRepository?
    private var sharedSyncCoordinator: SyncCoordinator?
    private var sharedMigrationController: MigrationController?
    
    init() {
        // Initialize core services
        self.locationService = LocationService()
        self.locationRepository = LocationRepositoryImpl(locationService: locationService)
        self.errorHandlingUseCase = ErrorHandlingUseCaseImpl()
        
        // Initialize Firebase services
        self.firebaseAuthService = FirebaseAuthService()
        self.firestoreService = FirestoreService()
    }
    
    // MARK: - Repository Factory Methods
    private func getPeeEventRepository(modelContext: ModelContext) -> PeeEventRepository {
        let contextId = ObjectIdentifier(modelContext)
        if let repository = peeEventRepositories[contextId] {
            return repository
        }
        let repository = PeeEventRepositoryImpl(modelContext: modelContext)
        peeEventRepositories[contextId] = repository
        return repository
    }
    
    private func getAuthRepository(modelContext: ModelContext) -> AuthRepository {
        // Use shared repository to ensure all views see the same state
        if let sharedRepository = sharedAuthRepository {
            return sharedRepository
        }
        
        // Create the first repository and share it across all contexts
        let repository = AuthRepositoryImpl(firebaseAuthService: firebaseAuthService, modelContext: modelContext)
        sharedAuthRepository = repository
        return repository
    }
    
    private func getUserRepository(modelContext: ModelContext) -> UserRepository {
        // Use shared repository to ensure all views see the same state
        if let sharedRepository = sharedUserRepository {
            return sharedRepository
        }
        
        // Create the first repository and share it across all contexts
        let repository = UserRepositoryImpl(modelContext: modelContext)
        sharedUserRepository = repository
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
    
    // MARK: - Public Repository Access
    func makeUserRepository(modelContext: ModelContext) -> UserRepository {
        return getUserRepository(modelContext: modelContext)
    }
    
    func makeAuthRepository(modelContext: ModelContext) -> AuthRepository {
        return getAuthRepository(modelContext: modelContext)
    }
    
    func makePeeEventRepository(modelContext: ModelContext) -> PeeEventRepository {
        return getPeeEventRepository(modelContext: modelContext)
    }
    
    // MARK: - Cloud Services Accessors
    func getFirestoreService() -> FirestoreService { firestoreService }

    // MARK: - Coordinators / Controllers
    func makeSyncCoordinator(modelContext: ModelContext) -> SyncCoordinator {
        if let shared = sharedSyncCoordinator { return shared }
        let coordinator = SyncCoordinator(
            peeEventRepository: getPeeEventRepository(modelContext: modelContext),
            userRepository: getUserRepository(modelContext: modelContext),
            firestoreService: firestoreService
        )
        sharedSyncCoordinator = coordinator
        return coordinator
    }
    
    func makeMigrationController(modelContext: ModelContext) -> MigrationController {
        if let shared = sharedMigrationController { return shared }
        let controller = MigrationControllerImpl(
            userRepository: getUserRepository(modelContext: modelContext),
            peeEventRepository: getPeeEventRepository(modelContext: modelContext),
            firestoreService: firestoreService
        )
        sharedMigrationController = controller
        return controller
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
            generateQualityTrendsUseCase: GenerateQualityTrendsUseCase(),
            generateHealthInsightsUseCase: GenerateHealthInsightsUseCase(repository: repository),
            analyzeHourlyPatternsUseCase: AnalyzeHourlyPatternsUseCase(),
            generateQualityDistributionUseCase: GenerateQualityDistributionUseCase(),
            generateWeeklyDataUseCase: GenerateWeeklyDataUseCase(repository: repository)
        )
    }
    
    // MARK: - Profile Feature View Models
    
    func makeAuthenticationViewModel(modelContext: ModelContext) -> AuthenticationViewModel {
        let authRepository = getAuthRepository(modelContext: modelContext)
        let userRepository = getUserRepository(modelContext: modelContext)
        let peeEventRepository = getPeeEventRepository(modelContext: modelContext)
        
        let authVM = AuthenticationViewModel(
            authenticateUserUseCase: AuthenticateUserUseCase(
                authRepository: authRepository,
                userRepository: userRepository,
                errorHandlingUseCase: errorHandlingUseCase
            ),
            createUserProfileUseCase: CreateUserProfileUseCase(
                userRepository: userRepository,
                errorHandlingUseCase: errorHandlingUseCase
            ),
            migrateGuestDataUseCase: MigrateGuestDataUseCase(
                userRepository: userRepository,
                peeEventRepository: peeEventRepository,
                errorHandlingUseCase: errorHandlingUseCase,
                migrationController: makeMigrationController(modelContext: modelContext)
            ),
            errorHandlingUseCase: errorHandlingUseCase
        )
        // Optional: inject skip use case wired to controller
        let skip = SkipMigrationUseCase(migrationController: makeMigrationController(modelContext: modelContext))
        authVM.setSkipMigrationUseCase(skip)
        return authVM
    }
    
    func makeProfileViewModel(modelContext: ModelContext) -> ProfileViewModel {
        let authRepository = getAuthRepository(modelContext: modelContext)
        let userRepository = getUserRepository(modelContext: modelContext)
        let peeEventRepository = getPeeEventRepository(modelContext: modelContext)
        let syncCoordinator = makeSyncCoordinator(modelContext: modelContext)
        
        return ProfileViewModel(
            authenticateUserUseCase: AuthenticateUserUseCase(
                authRepository: authRepository,
                userRepository: userRepository,
                errorHandlingUseCase: errorHandlingUseCase
            ),
            createUserProfileUseCase: CreateUserProfileUseCase(
                userRepository: userRepository,
                errorHandlingUseCase: errorHandlingUseCase
            ),
            updateUserPreferencesUseCase: UpdateUserPreferencesUseCase(
                userRepository: userRepository,
                errorHandlingUseCase: errorHandlingUseCase
            ),
            userRepository: userRepository,
            errorHandlingUseCase: errorHandlingUseCase,
            peeEventRepository: peeEventRepository,
            syncCoordinator: syncCoordinator
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
