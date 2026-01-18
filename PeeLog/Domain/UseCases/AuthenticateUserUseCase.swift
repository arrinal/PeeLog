//
//  AuthenticateUserUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation

// MARK: - Authentication Use Case Protocol
@MainActor
protocol AuthenticateUserUseCaseProtocol {
    func signInWithApple() async throws -> AuthResult
    func signOut() async throws
    func deleteAccount() async throws
    func refreshToken() async throws -> String
    func isTokenValid() async -> Bool
    func getCurrentUser() async -> User?
    func reloadUser() async throws
}

// MARK: - Authentication Use Case Implementation
@MainActor
final class AuthenticateUserUseCase: AuthenticateUserUseCaseProtocol {
    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let errorHandlingUseCase: ErrorHandlingUseCase
    
    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        errorHandlingUseCase: ErrorHandlingUseCase
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.errorHandlingUseCase = errorHandlingUseCase
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple() async throws -> AuthResult {
        do {
            // Update auth state to authenticating
            authRepository.updateAuthState(.authenticating)
            
            // Attempt Apple Sign In
            let authResult = try await authRepository.signInWithApple()
            
            // Save user locally
            try await userRepository.saveUser(authResult.user)
            
            // Update auth state to authenticated
            authRepository.updateAuthState(.authenticated(authResult.user))
            
            // Sync user data from server
            try? await userRepository.syncUserData()
            
            return authResult
            
        } catch {
            let context = ErrorContextHelper.createAppleSignInContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            
            if let authError = error as? AuthError {
                authRepository.updateAuthState(.error(authError))
                throw authError
            } else {
                let unknownAuthError = AuthError.unknown(result.userMessage)
                authRepository.updateAuthState(.error(unknownAuthError))
                throw unknownAuthError
            }
        }
    }
    
    // MARK: - Sign Out & Account Management
    
    func signOut() async throws {
        do {
            // Clear all authenticated users from local storage FIRST
            try await userRepository.clearAuthenticatedUsers()
            
            // Sign out from auth repository (this will trigger handleFirebaseSignOut)
            try await authRepository.signOut()
            
            // DON'T override the auth state here - observer will set unauthenticated
            
        } catch {
            let context = ErrorContextHelper.createSignOutContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    func deleteAccount() async throws {
        do {
            // Delete account from auth repository
            try await authRepository.deleteAccount()
            
            // Clear all local data
            try await userRepository.clearAllLocalData()
            
            // Update auth state to unauthenticated
            authRepository.updateAuthState(.unauthenticated)
            
        } catch {
            let context = ErrorContextHelper.createDeleteAccountContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    // MARK: - Token Management
    
    func refreshToken() async throws -> String {
        do {
            return try await authRepository.refreshToken()
        } catch {
            let context = ErrorContextHelper.createRefreshTokenContext()
            let _ = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.tokenExpired
        }
    }
    
    func isTokenValid() async -> Bool {
        return await authRepository.isTokenValid()
    }
    
    // MARK: - User State
    
    func getCurrentUser() async -> User? {
        return await authRepository.getCurrentUser()
    }
    
    func reloadUser() async throws {
        do {
            try await authRepository.reloadUser()
        } catch {
            let context = ErrorContextHelper.createEmailVerificationContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
} 