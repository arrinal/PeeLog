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
    private let syncControl = SyncControl()
    private var analyticsRepository: AnalyticsRepository?
    private var remoteAnalyticsService: RemoteAnalyticsService?
    private var analyticsCache: AnalyticsCache = AnalyticsCache()
    private let networkMonitor = NetworkMonitor.shared
    private var subscriptionRepository: SubscriptionRepository?
    private var aiInsightRepository: AIInsightRepository?
    
    init() {
        // Initialize core services
        self.locationService = LocationService()
        self.locationRepository = LocationRepositoryImpl(locationService: locationService)
        self.errorHandlingUseCase = ErrorHandlingUseCaseImpl()
        
        // Initialize Firebase services
        self.firebaseAuthService = FirebaseAuthService()
        self.firestoreService = FirestoreService()
        // Initialize Remote Analytics service
        let analyticsConfig = RemoteAnalyticsService.Config(projectId: "peelog-d3e84")
        self.remoteAnalyticsService = RemoteAnalyticsService(config: analyticsConfig)
        // Start network monitoring
        self.networkMonitor.start()
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
    func getSyncControl() -> SyncControl { syncControl }
    func getAnalyticsRepository() -> AnalyticsRepository {
        if let repo = analyticsRepository { return repo }
        let service = remoteAnalyticsService ?? RemoteAnalyticsService(config: .init(projectId: "peelog-d3e84"))
        let repo = AnalyticsRepositoryImpl(service: service, cache: analyticsCache)
        analyticsRepository = repo
        return repo
    }
    
    func getNetworkMonitor() -> NetworkMonitor { networkMonitor }
    func getSubscriptionRepository() -> SubscriptionRepository {
        if let repo = subscriptionRepository { return repo }
        let repo = SubscriptionRepositoryImpl(service: SubscriptionService())
        subscriptionRepository = repo
        return repo
    }

    func getAIInsightRepository() -> AIInsightRepository {
        if let repo = aiInsightRepository { return repo }
        let repo = AIInsightRepositoryImpl()
        aiInsightRepository = repo
        return repo
    }

    // MARK: - Coordinators / Controllers
    func makeSyncCoordinator(modelContext: ModelContext) -> SyncCoordinator {
        if let shared = sharedSyncCoordinator { return shared }
        let coordinator = SyncCoordinator(
            peeEventRepository: getPeeEventRepository(modelContext: modelContext),
            userRepository: getUserRepository(modelContext: modelContext),
            firestoreService: firestoreService,
            syncControl: syncControl
        )
        sharedSyncCoordinator = coordinator
        return coordinator
    }
    
    // Legacy migration controller removed
    
    // MARK: - View Model Factory Methods
    func makeHomeViewModel(modelContext: ModelContext) -> HomeViewModel {
        let repository = getPeeEventRepository(modelContext: modelContext)
        return HomeViewModel(
            getTodaysPeeEventsUseCase: GetTodaysPeeEventsUseCase(repository: repository),
            deleteEventUseCase: DeletePeeEventUseCase(repository: repository),
            syncCoordinator: makeSyncCoordinator(modelContext: modelContext)
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
            errorHandlingUseCase: errorHandlingUseCase,
            syncCoordinator: makeSyncCoordinator(modelContext: modelContext)
        )
    }
    
    func makeStatisticsViewModel(modelContext: ModelContext) -> StatisticsViewModel {
        return StatisticsViewModel(
            analyticsRepository: getAnalyticsRepository(),
            aiInsightRepository: getAIInsightRepository()
        )
    }
    
    // MARK: - Profile Feature View Models
    
    func makeProfileViewModel(modelContext: ModelContext) -> ProfileViewModel {
        let authRepository = getAuthRepository(modelContext: modelContext)
        let userRepository = getUserRepository(modelContext: modelContext)
        let peeEventRepository = getPeeEventRepository(modelContext: modelContext)
        let syncCoordinator = makeSyncCoordinator(modelContext: modelContext)
        let exportDataUseCase = ExportDataUseCase(peeEventRepository: peeEventRepository)
        
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
            exportDataUseCase: exportDataUseCase,
            userRepository: userRepository,
            errorHandlingUseCase: errorHandlingUseCase,
            peeEventRepository: peeEventRepository,
            syncCoordinator: syncCoordinator
        )
    }

    // MARK: - Subscription ViewModel
    func makeSubscriptionViewModel(modelContext: ModelContext) -> SubscriptionViewModel {
        let subRepo = getSubscriptionRepository()
        let userRepo = getUserRepository(modelContext: modelContext)
        let authRepo = getAuthRepository(modelContext: modelContext)
        let authenticateUserUseCase = AuthenticateUserUseCase(
            authRepository: authRepo,
            userRepository: userRepo,
            errorHandlingUseCase: errorHandlingUseCase
        )
        return SubscriptionViewModel(
            checkStatus: CheckSubscriptionStatusUseCase(repository: subRepo, userRepository: userRepo),
            purchaseUseCase: PurchaseSubscriptionUseCase(repository: subRepo),
            restoreUseCase: RestorePurchasesUseCase(repository: subRepo),
            authenticateUserUseCase: authenticateUserUseCase,
            authRepository: authRepo,
            userRepository: userRepo
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
