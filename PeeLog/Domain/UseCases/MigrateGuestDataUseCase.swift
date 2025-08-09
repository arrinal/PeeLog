//
//  MigrateGuestDataUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// MARK: - Migration Error
enum MigrationError: Error, LocalizedError {
    case sourceUserNotGuest
    case migrationInProgress
    case dataTransferFailed(String)
    case targetUserInvalid
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .sourceUserNotGuest:
            return "Source user is not a guest user"
        case .migrationInProgress:
            return "Migration is already in progress"
        case .dataTransferFailed(let message):
            return "Data transfer failed: \(message)"
        case .targetUserInvalid:
            return "Target user is invalid"
        case .unknown(let message):
            return "Migration error: \(message)"
        }
    }
}

// MARK: - Migration Status
enum MigrationStatus: Equatable {
    case idle
    case preparingData
    case migratingUser
    case transferringEvents
    case syncingToServer
    case cleaningUp
    case completed
    case failed(String)
    
    var isActive: Bool {
        switch self {
        case .idle, .completed, .failed:
            return false
        default:
            return true
        }
    }
}

// MARK: - Migrate Guest Data Use Case Protocol
@MainActor
protocol MigrateGuestDataUseCaseProtocol {
    func migrateGuestData(guestUser: User, to authenticatedUser: User) async throws
    func canMigrateData(from guestUser: User) async -> Bool
    func estimateMigrationTime(for guestUser: User) async -> TimeInterval
    func getMigrationStatus() async -> MigrationStatus
}

// MARK: - Migrate Guest Data Use Case Implementation
@MainActor
final class MigrateGuestDataUseCase: MigrateGuestDataUseCaseProtocol {
    private let userRepository: UserRepository
    private let peeEventRepository: PeeEventRepository
    private let errorHandlingUseCase: ErrorHandlingUseCase
    private let migrationController: MigrationController
    
    @Published private(set) var migrationStatus: MigrationStatus = .idle
    
    init(
        userRepository: UserRepository,
        peeEventRepository: PeeEventRepository,
        errorHandlingUseCase: ErrorHandlingUseCase,
        migrationController: MigrationController
    ) {
        self.userRepository = userRepository
        self.peeEventRepository = peeEventRepository
        self.errorHandlingUseCase = errorHandlingUseCase
        self.migrationController = migrationController
    }
    
    func migrateGuestData(guestUser: User, to authenticatedUser: User) async throws {
        do {
            // Validate inputs
            guard guestUser.isGuest else {
                throw MigrationError.sourceUserNotGuest
            }
            
            guard !authenticatedUser.isGuest else {
                throw MigrationError.targetUserInvalid
            }
            
            guard migrationStatus == .idle else {
                throw MigrationError.migrationInProgress
            }
            
            // Start migration process
            migrationStatus = .preparingData
            
            // Step 1: Get all guest user's pee events
            let guestEvents = peeEventRepository.getAllEvents()
            let guestEventsForUser = guestEvents // All events have non-nil timestamps
            
            // Delegate the heavy lifting to MigrationController (cloud + local)
            migrationStatus = .migratingUser
            try await migrationController.migrateGuestData(guestUser: guestUser, to: authenticatedUser)
            migrationStatus = .completed
            
        } catch {
            let context = ErrorContextHelper.createMigrateGuestDataContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            migrationStatus = .failed(result.userMessage)
            throw result.error
        }
    }
    
    func canMigrateData(from guestUser: User) async -> Bool {
        // Check if user is guest and has data to migrate
        guard guestUser.isGuest else { return false }
        
        // Check if there are any pee events to migrate
        let events = peeEventRepository.getAllEvents()
        return !events.isEmpty
    }
    
    func estimateMigrationTime(for guestUser: User) async -> TimeInterval {
        // Estimate migration time based on data volume
        let events = peeEventRepository.getAllEvents()
        let eventCount = events.count
        
        // Base time for user migration: 2 seconds
        let baseTime: TimeInterval = 2.0
        
        // Additional time per event: 0.1 seconds
        let timePerEvent: TimeInterval = 0.1
        
        return baseTime + (Double(eventCount) * timePerEvent)
    }
    
    func getMigrationStatus() async -> MigrationStatus {
        return migrationStatus
    }
} 