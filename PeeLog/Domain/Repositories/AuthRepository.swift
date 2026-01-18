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
    case error(AuthError)
    
    var user: User? {
        switch self {
        case .authenticated(let user):
            return user
        default:
            return nil
        }
    }
    
    var isAuthenticated: Bool {
        switch self {
        case .authenticated:
            return true
        default:
            return false
        }
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
    func signInWithApple() async throws -> AuthResult
    func signOut() async throws
    func deleteAccount() async throws
    
    // Token management
    func refreshToken() async throws -> String
    func isTokenValid() async -> Bool
    func getValidToken() async throws -> String?
    
    // User state management
    func getCurrentUser() async -> User?
    func updateAuthState(_ state: AuthState)
    func isUserAuthenticated() async -> Bool
    
    func reloadUser() async throws
} 
