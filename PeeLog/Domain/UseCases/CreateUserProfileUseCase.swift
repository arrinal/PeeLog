//
//  CreateUserProfileUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// MARK: - Create User Profile Use Case Protocol
@MainActor
protocol CreateUserProfileUseCaseProtocol {
    func createUserProfile(email: String?, displayName: String?, authProvider: AuthProvider, appleUserId: String?) async throws -> User
    func createGuestProfile() async throws -> User
    func updateProfile(user: User, displayName: String?, email: String?) async throws -> User
    func deleteProfile(user: User) async throws
}

// MARK: - Create User Profile Use Case Implementation
@MainActor
final class CreateUserProfileUseCase: CreateUserProfileUseCaseProtocol {
    private let userRepository: UserRepository
    private let errorHandlingUseCase: ErrorHandlingUseCase
    
    init(
        userRepository: UserRepository,
        errorHandlingUseCase: ErrorHandlingUseCase
    ) {
        self.userRepository = userRepository
        self.errorHandlingUseCase = errorHandlingUseCase
    }
    
    func createUserProfile(
        email: String?,
        displayName: String?,
        authProvider: AuthProvider,
        appleUserId: String? = nil
    ) async throws -> User {
        do {
            // Create user based on auth provider
            let user: User
            
            switch authProvider {
            case .email:
                guard let email = email else {
                    throw UserRepositoryError.invalidData("Email is required for email authentication")
                }
                user = User.createEmailUser(email: email, displayName: displayName)
                
            case .apple:
                guard let appleUserId = appleUserId else {
                    throw UserRepositoryError.invalidData("Apple user ID is required for Apple authentication")
                }
                user = User.createAppleUser(appleUserId: appleUserId, email: email, displayName: displayName)
                
            case .guest:
                user = User.createGuest()
            }
            
            // Save user locally
            try await userRepository.saveUser(user)
            
            // Sync to server if not guest
            if !user.isGuest {
                try? await userRepository.syncUserToServer(user)
            }
            
            return user
            
        } catch {
            let context = ErrorContext(operation: "Create User Profile", userAction: "User profile creation")
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw result.error
        }
    }
    
    func createGuestProfile() async throws -> User {
        return try await createUserProfile(
            email: nil,
            displayName: nil,
            authProvider: .guest,
            appleUserId: nil
        )
    }
    
    func updateProfile(user: User, displayName: String?, email: String?) async throws -> User {
        do {
            // Update user properties
            if let displayName = displayName {
                user.displayName = displayName
            }
            
            if let email = email {
                user.email = email
            }
            
            user.updatedAt = Date()
            
            // Save updated user
            try await userRepository.updateUser(user)
            
            // Sync to server if not guest
            if !user.isGuest {
                try? await userRepository.syncUserToServer(user)
            }
            
            return user
            
        } catch {
            let context = ErrorContext(operation: "Update User Profile", userAction: "User profile update")
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw result.error
        }
    }
    
    func deleteProfile(user: User) async throws {
        do {
            // Delete user from local storage
            try await userRepository.deleteUser(user)
            
            // Note: Actual account deletion should be handled by AuthenticateUserUseCase
            // This just removes the local profile data
            
        } catch {
            let context = ErrorContext(operation: "Delete User Profile", userAction: "User profile deletion")
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw result.error
        }
    }
} 