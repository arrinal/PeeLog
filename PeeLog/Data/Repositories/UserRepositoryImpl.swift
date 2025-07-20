//
//  UserRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class UserRepositoryImpl: UserRepository {
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Subjects for publishing
    private let currentUserSubject = CurrentValueSubject<User?, Never>(nil)
    private let syncStatusSubject = CurrentValueSubject<SyncStatus, Never>(.idle)
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    
    // Flag to force guest user priority during sign-out transitions
    private var prioritizeGuest = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Published Properties
    
    var currentUser: AnyPublisher<User?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }
    
    var syncStatus: AnyPublisher<SyncStatus, Never> {
        syncStatusSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Local User Management
    
    func getCurrentUser() async -> User? {
        // During sign-out transitions, prioritize guest users to prevent 
        // returning stale authenticated users
        if prioritizeGuest {
            if let guestUser = await getGuestUser() {
                currentUserSubject.send(guestUser)
                return guestUser
            }
            // No guest user found, reset flag and continue normal logic
            prioritizeGuest = false
        }
        
        // Normal priority: authenticated users first, then guest users
        if let authenticatedUser = await getAuthenticatedUser() {
            currentUserSubject.send(authenticatedUser)
            return authenticatedUser
        }
        
        if let guestUser = await getGuestUser() {
            currentUserSubject.send(guestUser)
            return guestUser
        }
        
        return nil
    }
    
    func saveUser(_ user: User) async throws {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            modelContext.insert(user)
            try modelContext.save()
            currentUserSubject.send(user)
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    func updateUser(_ user: User) async throws {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            user.updatedAt = Date()
            try modelContext.save()
            currentUserSubject.send(user)
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    func deleteUser(_ user: User) async throws {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            modelContext.delete(user)
            try modelContext.save()
            
            if currentUserSubject.value?.id == user.id {
                currentUserSubject.send(nil)
            }
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    func clearUserData() async throws {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            if let currentUser = currentUserSubject.value {
                modelContext.delete(currentUser)
                try modelContext.save()
                currentUserSubject.send(nil)
            }
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    func clearAuthenticatedUsers() async throws {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            // Reset current user immediately if it was an authenticated user
            if let currentUser = currentUserSubject.value, !currentUser.isGuest {
                currentUserSubject.send(nil)
            }
            
            // Set flag to prioritize guest users during the transition period
            prioritizeGuest = true
            
            // Get all authenticated users (non-guest) in a single transaction
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.isGuest == false }
            )
            
            // Perform deletion in a transaction-like manner
            let authenticatedUsers = try modelContext.fetch(descriptor)
            
            // If no authenticated users, we're done
            guard !authenticatedUsers.isEmpty else {
                return
            }
            
            // Delete all authenticated users in one batch
            for user in authenticatedUsers {
                modelContext.delete(user)
            }
            
            // Force save with error handling
            do {
                try modelContext.save()
            } catch {
                // If save fails, rollback by not completing the operation
                throw UserRepositoryError.saveFailed("Failed to save changes while clearing authenticated users: \(error.localizedDescription)")
            }
            
            // Verification step - ensure clearing was successful
            let verificationDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.isGuest == false }
            )
            let remainingUsers = try modelContext.fetch(verificationDescriptor)
            
            if !remainingUsers.isEmpty {
                // This should not happen, but if it does, we have a serious consistency issue
                throw UserRepositoryError.saveFailed("Failed to clear authenticated users completely. \(remainingUsers.count) users remain.")
            }
            
        } catch {
            // Reset flag on error
            prioritizeGuest = false
            // Ensure we re-throw with proper error context
            if error is UserRepositoryError {
                throw error
            } else {
                throw UserRepositoryError.saveFailed("Failed to clear authenticated users: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - User Preferences Management
    
    func updateUserPreferences(_ preferences: UserPreferences) async throws {
        guard let user = await getCurrentUser() else {
            throw UserRepositoryError.userNotFound
        }
        
        user.updatePreferences(preferences)
        try await updateUser(user)
    }
    
    func getUserPreferences() async -> UserPreferences? {
        guard let user = await getCurrentUser() else {
            return nil
        }
        return user.preferences
    }
    
    // MARK: - Profile Management
    
    func updateDisplayName(_ displayName: String) async throws {
        guard let user = await getCurrentUser() else {
            throw UserRepositoryError.userNotFound
        }
        
        user.displayName = displayName
        try await updateUser(user)
    }
    
    func updateEmail(_ email: String) async throws {
        guard let user = await getCurrentUser() else {
            throw UserRepositoryError.userNotFound
        }
        
        user.email = email
        try await updateUser(user)
    }
    
    // MARK: - Data Synchronization
    
    func syncUserData() async throws {
        guard let user = await getCurrentUser() else {
            throw UserRepositoryError.userNotFound
        }
        
        // Skip sync for guest users
        if user.isGuest || !user.preferences.syncEnabled {
            return
        }
        
        syncStatusSubject.send(.syncing)
        
        do {
            // TODO: Implement Firebase sync when backend is ready
            // For now, just simulate sync
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            syncStatusSubject.send(.synced)
        } catch {
            syncStatusSubject.send(.error(error.localizedDescription))
            throw UserRepositoryError.syncFailed(error.localizedDescription)
        }
    }
    
    func syncUserToServer(_ user: User) async throws {
        // Skip sync for guest users
        if user.isGuest || !user.preferences.syncEnabled {
            return
        }
        
        syncStatusSubject.send(.syncing)
        
        do {
            // TODO: Implement Firebase Firestore sync
            // This will upload user data to Firebase
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            syncStatusSubject.send(.synced)
        } catch {
            syncStatusSubject.send(.error(error.localizedDescription))
            throw UserRepositoryError.syncFailed(error.localizedDescription)
        }
    }
    
    func loadUserFromServer() async throws -> User? {
        syncStatusSubject.send(.syncing)
        
        do {
            // TODO: Implement Firebase Firestore fetch
            // This will download user data from Firebase
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            syncStatusSubject.send(.synced)
            return nil // Will return actual user when implemented
        } catch {
            syncStatusSubject.send(.error(error.localizedDescription))
            throw UserRepositoryError.syncFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Guest User Management
    
    func createGuestUser() async throws -> User {
        // Check if guest user already exists
        if let existingGuest = await getGuestUser() {
            // Reset the prioritize flag since we found an existing guest
            prioritizeGuest = false
            return existingGuest
        }
        
        let guestUser = User.createGuest()
        try await saveUser(guestUser)
        
        // Reset the prioritize flag after creating new guest user
        prioritizeGuest = false
        return guestUser
    }
    
    func isGuestUser() async -> Bool {
        guard let user = await getCurrentUser() else {
            return false
        }
        return user.isGuest
    }
    
    func migrateGuestToAuthenticated(_ authenticatedUser: User) async throws {
        // Get current guest user
        guard let guestUser = await getGuestUser() else {
            throw UserRepositoryError.userNotFound
        }
        
        // Preserve guest preferences
        let guestPreferences = guestUser.preferences
        authenticatedUser.updatePreferences(guestPreferences)
        
        // Save authenticated user
        try await saveUser(authenticatedUser)
        
        // Delete guest user
        try await deleteUser(guestUser)
    }
    
    // MARK: - Data Export and Import
    
    func exportUserData() async throws -> Data {
        guard let user = await getCurrentUser() else {
            throw UserRepositoryError.userNotFound
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(user)
        } catch {
            throw UserRepositoryError.saveFailed("Failed to encode user data: \(error.localizedDescription)")
        }
    }
    
    func importUserData(_ data: Data) async throws {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let user = try decoder.decode(User.self, from: data)
            
            try await saveUser(user)
        } catch {
            throw UserRepositoryError.loadFailed("Failed to decode user data: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Utility Methods
    
    func getUserById(_ id: UUID) async -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        
        do {
            let users = try modelContext.fetch(descriptor)
            return users.first
        } catch {
            return nil
        }
    }
    
    func getAllLocalUsers() async -> [User] {
        let descriptor = FetchDescriptor<User>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }
    
    func clearAllLocalData() async throws {
        do {
            let users = await getAllLocalUsers()
            for user in users {
                modelContext.delete(user)
            }
            try modelContext.save()
            currentUserSubject.send(nil)
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Private Helpers
    
    private func getAuthenticatedUser() async -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isGuest == false },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        
        do {
            let users = try modelContext.fetch(descriptor)
            return users.first
        } catch {
            return nil
        }
    }
    
    private func getGuestUser() async -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.isGuest == true }
        )
        
        do {
            let users = try modelContext.fetch(descriptor)
            return users.first
        } catch {
            return nil
        }
    }
} 