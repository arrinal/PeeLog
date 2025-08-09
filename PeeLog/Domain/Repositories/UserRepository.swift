//
//  UserRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData
import Combine

// MARK: - User Repository Error
enum UserRepositoryError: Error, LocalizedError, Equatable {
    case userNotFound
    case saveFailed(String)
    case loadFailed(String)
    case syncFailed(String)
    case invalidData(String)
    case networkError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .saveFailed(let message):
            return "Failed to save user data: \(message)"
        case .loadFailed(let message):
            return "Failed to load user data: \(message)"
        case .syncFailed(let message):
            return "Failed to sync user data: \(message)"
        case .invalidData(let message):
            return "Invalid user data: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return "\(message)"
        }
    }
}

// MARK: - Sync Status
enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced
    case error(String)
    
    var isSyncing: Bool {
        if case .syncing = self {
            return true
        }
        return false
    }
    
    var hasError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

// MARK: - User Repository Protocol
@MainActor
protocol UserRepository: AnyObject {
    // Published properties for observing user state
    var currentUser: AnyPublisher<User?, Never> { get }
    var syncStatus: AnyPublisher<SyncStatus, Never> { get }
    var isLoading: AnyPublisher<Bool, Never> { get }
    
    // Local user management
    func getCurrentUser() async -> User?
    func saveUser(_ user: User) async throws
    func updateUser(_ user: User) async throws
    func deleteUser(_ user: User) async throws
    func clearUserData() async throws
    func clearAuthenticatedUsers() async throws
    
    // User preferences management
    func updateUserPreferences(_ preferences: UserPreferences) async throws
    func getUserPreferences() async -> UserPreferences?
    
    // Profile management
    func updateDisplayName(_ displayName: String) async throws
    func updateEmail(_ email: String) async throws
    
    // Data synchronization
    func syncUserData() async throws
    func syncUserToServer(_ user: User) async throws
    func loadUserFromServer() async throws -> User?
    
    // Guest user management
    func createGuestUser() async throws -> User
    func isGuestUser() async -> Bool
    func migrateGuestToAuthenticated(_ authenticatedUser: User) async throws
    
    // Data export and import
    func exportUserData() async throws -> Data
    func importUserData(_ data: Data) async throws
    
    // Utility methods
    func getUserById(_ id: UUID) async -> User?
    func getAllLocalUsers() async -> [User]
    func clearAllLocalData() async throws
} 
