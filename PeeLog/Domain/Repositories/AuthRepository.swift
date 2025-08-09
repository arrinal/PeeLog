//
//  AuthRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import Combine

// MARK: - Authentication Error
enum AuthError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case invalidEmail
    case emailNotVerified
    case networkError(String)
    case serviceUnavailable
    case tokenExpired
    case noToken
    case noRefreshToken
    case userDisabled
    case tooManyRequests
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .userNotFound:
            return "User not found"
        case .emailAlreadyInUse:
            return "Email is already registered"
        case .weakPassword:
            return "Password is too weak"
        case .invalidEmail:
            return "Invalid email format"
        case .emailNotVerified:
            return "Please verify your email before signing in"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serviceUnavailable:
            return "Authentication service is unavailable"
        case .tokenExpired:
            return "Session expired. Please sign in again"
        case .noToken:
            return "No authentication token found"
        case .noRefreshToken:
            return "No refresh token available"
        case .userDisabled:
            return "User account has been disabled"
        case .tooManyRequests:
            return "Too many requests. Please try again later"
        case .unknown(let message):
            return "\(message)"
        }
    }
}

// MARK: - Authentication Result
struct AuthResult {
    let user: User
    let accessToken: String
    let refreshToken: String?
    
    init(user: User, accessToken: String, refreshToken: String? = nil) {
        self.user = user
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

// MARK: - Authentication State
enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case guest(User)
    case error(AuthError)
    
    var user: User? {
        switch self {
        case .authenticated(let user), .guest(let user):
            return user
        default:
            return nil
        }
    }
    
    var isAuthenticated: Bool {
        switch self {
        case .authenticated, .guest:
            return true
        default:
            return false
        }
    }
    
    var isGuest: Bool {
        if case .guest = self {
            return true
        }
        return false
    }
}

// MARK: - Auth Repository Protocol
@MainActor
protocol AuthRepository: AnyObject {
    // Published properties for observing authentication state
    var authState: AnyPublisher<AuthState, Never> { get }
    var currentUser: AnyPublisher<User?, Never> { get }
    var isAuthenticated: AnyPublisher<Bool, Never> { get }
    var isLoading: AnyPublisher<Bool, Never> { get }
    
    // Authentication methods
    func signInWithEmail(_ email: String, password: String) async throws -> AuthResult
    func registerWithEmail(_ email: String, password: String, displayName: String?) async throws -> AuthResult
    func signInWithApple() async throws -> AuthResult
    func signInAsGuest() async throws -> User
    func signOut() async throws
    func deleteAccount() async throws
    
    // Password reset
    func sendPasswordReset(toEmail email: String) async throws
    
    // Email verification
    func sendEmailVerification() async throws
    func sendEmailVerification(to user: User) async throws
    func sendEmailVerification(toEmail email: String, password: String) async throws
    func isEmailVerified() -> Bool
    func checkEmailVerificationStatus() async throws -> Bool
    func checkEmailVerificationStatus(email: String, password: String) async throws -> Bool
    func reloadUser() async throws
    
    // Token management
    func refreshToken() async throws -> String
    func isTokenValid() async -> Bool
    func getValidToken() async throws -> String?
    
    // Guest data migration
    func migrateGuestData(to authenticatedUser: User) async throws
    
    // User state management
    func getCurrentUser() async -> User?
    func updateAuthState(_ state: AuthState)
    func isUserAuthenticated() async -> Bool
    
    // Utility methods
    func isEmailValid(_ email: String) -> Bool
    func isPasswordValid(_ password: String) -> Bool
} 
