//
//  AuthenticateUserUseCase.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import Combine

// MARK: - Validation Utility
struct ValidationUtility {
    static func isEmailValid(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    static func isPasswordValid(_ password: String) -> Bool {
        // Minimum 6 characters for password
        return password.count >= 6
    }
}

// MARK: - Authentication Use Case Protocol
@MainActor
protocol AuthenticateUserUseCaseProtocol {
    func signInWithEmail(_ email: String, password: String) async throws -> AuthResult
    func registerWithEmail(_ email: String, password: String, displayName: String?) async throws -> AuthResult
    func signInWithApple() async throws -> AuthResult
    func signInAsGuest() async throws -> User
    func signOut() async throws
    func deleteAccount() async throws
    func refreshToken() async throws -> String
    func isTokenValid() async -> Bool
    func getCurrentUser() async -> User?
    func isEmailValid(_ email: String) -> Bool
    func isPasswordValid(_ password: String) -> Bool
    func sendPasswordReset(toEmail email: String) async throws
    func sendEmailVerification() async throws
    func sendEmailVerification(toEmail email: String, password: String) async throws
    func isEmailVerified() -> Bool
    func checkEmailVerificationStatus() async throws -> Bool
    func checkEmailVerificationStatus(email: String, password: String) async throws -> Bool
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
    
    // MARK: - Email/Password Authentication
    
    func signInWithEmail(_ email: String, password: String) async throws -> AuthResult {
        do {
            // Validate input
            guard isEmailValid(email) else {
                throw AuthError.invalidEmail
            }
            
            guard isPasswordValid(password) else {
                throw AuthError.weakPassword
            }
            
            // Update auth state to authenticating
            authRepository.updateAuthState(.authenticating)
            
            // Attempt authentication
            let authResult = try await authRepository.signInWithEmail(email, password: password)
            
            // Save user locally
            try await userRepository.saveUser(authResult.user)
            
            // Update auth state to authenticated
            authRepository.updateAuthState(.authenticated(authResult.user))
            
            // Sync user data from server
            try? await userRepository.syncUserData()
            
            return authResult
            
        } catch {
            let context = ErrorContextHelper.createEmailSignInContext()
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
    
    func registerWithEmail(_ email: String, password: String, displayName: String?) async throws -> AuthResult {
        do {
            // Validate input
            guard isEmailValid(email) else {
                throw AuthError.invalidEmail
            }
            
            guard isPasswordValid(password) else {
                throw AuthError.weakPassword
            }
            
            // Update auth state to authenticating
            authRepository.updateAuthState(.authenticating)
            
            // Attempt registration
            let authResult = try await authRepository.registerWithEmail(email, password: password, displayName: displayName)
            
            // Don't save user locally or update auth state since user is not verified yet
            // These will be done when the user actually signs in after verification
            
            return authResult
            
        } catch {
            let context = ErrorContextHelper.createEmailRegistrationContext()
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
    
    // MARK: - Guest Mode
    
    func signInAsGuest() async throws -> User {
        do {
            // Create guest user
            let guestUser = try await userRepository.createGuestUser()
            
            // Update auth state to guest
            authRepository.updateAuthState(.guest(guestUser))
            
            return guestUser
            
        } catch {
            let context = ErrorContextHelper.createGuestSignInContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    // MARK: - Sign Out & Account Management
    
    func signOut() async throws {
        do {
            // Clear all authenticated users from local storage FIRST
            try await userRepository.clearAuthenticatedUsers()
            
            // Sign out from auth repository (this will trigger handleFirebaseSignOut)
            try await authRepository.signOut()
            
            // DON'T override the auth state here - let handleFirebaseSignOut determine
            // the correct state based on whether guest users exist
            
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
    
    // MARK: - Validation
    
    func isEmailValid(_ email: String) -> Bool {
        return ValidationUtility.isEmailValid(email)
    }
    
    func isPasswordValid(_ password: String) -> Bool {
        return ValidationUtility.isPasswordValid(password)
    }
    
    func sendPasswordReset(toEmail email: String) async throws {
        do {
            try await authRepository.sendPasswordReset(toEmail: email)
        } catch {
            let context = ErrorContextHelper.createPasswordResetContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    // MARK: - Email Verification
    
    func sendEmailVerification() async throws {
        do {
            try await authRepository.sendEmailVerification()
        } catch {
            let context = ErrorContextHelper.createEmailVerificationContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    func sendEmailVerification(toEmail email: String, password: String) async throws {
        do {
            try await authRepository.sendEmailVerification(toEmail: email, password: password)
        } catch {
            let context = ErrorContextHelper.createEmailVerificationContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    func isEmailVerified() -> Bool {
        return authRepository.isEmailVerified()
    }
    
    func checkEmailVerificationStatus() async throws -> Bool {
        do {
            return try await authRepository.checkEmailVerificationStatus()
        } catch {
            let context = ErrorContextHelper.createEmailVerificationContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
    }
    
    func checkEmailVerificationStatus(email: String, password: String) async throws -> Bool {
        do {
            return try await authRepository.checkEmailVerificationStatus(email: email, password: password)
        } catch {
            let context = ErrorContextHelper.createEmailVerificationContext()
            let result = errorHandlingUseCase.handleError(error, context: context)
            throw AuthError.unknown(result.userMessage)
        }
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