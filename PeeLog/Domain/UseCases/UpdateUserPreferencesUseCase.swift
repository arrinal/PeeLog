//
//  UpdateUserPreferencesUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// MARK: - Update User Preferences Use Case Protocol
@MainActor
protocol UpdateUserPreferencesUseCaseProtocol {
    func updatePreferences(user: User, preferences: UserPreferences) async throws -> User
    // TODO: Re-enable in next release
    // func updateNotificationSettings(user: User, enabled: Bool) async throws -> User
    func updateUnits(user: User, units: MeasurementUnit) async throws -> User
    func updateTheme(user: User, theme: ThemePreference) async throws -> User
    func updateSyncSettings(user: User, syncEnabled: Bool) async throws -> User
    func resetToDefaults(user: User) async throws -> User
    func getPreferences(user: User) async -> UserPreferences
}

// MARK: - Update User Preferences Use Case Implementation
@MainActor
final class UpdateUserPreferencesUseCase: UpdateUserPreferencesUseCaseProtocol {
    private let userRepository: UserRepository
    private let errorHandlingUseCase: ErrorHandlingUseCase
    
    init(
        userRepository: UserRepository,
        errorHandlingUseCase: ErrorHandlingUseCase
    ) {
        self.userRepository = userRepository
        self.errorHandlingUseCase = errorHandlingUseCase
    }
    
    func updatePreferences(user: User, preferences: UserPreferences) async throws -> User {
        do {
            // Update user preferences
            user.updatePreferences(preferences)
            
            // Save updated user
            try await userRepository.updateUser(user)
            
            // Sync to server
            try? await userRepository.syncUserToServer(user)
            
            return user
            
        } catch {
            let context = ErrorContextHelper.createUpdateUserPreferencesContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw result.error
        }
    }
    
    // TODO: Re-enable and enhance push notifications in next release
    // func updateNotificationSettings(user: User, enabled: Bool) async throws -> User {
    //     var preferences = user.preferences
    //     preferences.notificationsEnabled = enabled
    //     return try await updatePreferences(user: user, preferences: preferences)
    // }
    
    func updateUnits(user: User, units: MeasurementUnit) async throws -> User {
        var preferences = user.preferences
        preferences.units = units
        return try await updatePreferences(user: user, preferences: preferences)
    }
    
    func updateTheme(user: User, theme: ThemePreference) async throws -> User {
        var preferences = user.preferences
        preferences.theme = theme
        return try await updatePreferences(user: user, preferences: preferences)
    }
    
    func updateSyncSettings(user: User, syncEnabled: Bool) async throws -> User {
        var preferences = user.preferences
        preferences.syncEnabled = syncEnabled
        return try await updatePreferences(user: user, preferences: preferences)
    }
    
    func resetToDefaults(user: User) async throws -> User {
        let defaultPreferences = UserPreferences.default
        return try await updatePreferences(user: user, preferences: defaultPreferences)
    }
    
    func getPreferences(user: User) async -> UserPreferences {
        return user.preferences
    }
} 