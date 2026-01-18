//
//  AuthenticationViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI

@MainActor
final class AuthenticationViewModel: ObservableObject {
    // MARK: - Use Cases
    private let authenticateUserUseCase: AuthenticateUserUseCaseProtocol
    private let errorHandlingUseCase: ErrorHandlingUseCase
    private var syncControl: SyncControl?
    
    // MARK: - Published Properties
    @Published var authState: AuthState = .unauthenticated
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    init(
        authenticateUserUseCase: AuthenticateUserUseCaseProtocol,
        errorHandlingUseCase: ErrorHandlingUseCase
    ) {
        self.authenticateUserUseCase = authenticateUserUseCase
        self.errorHandlingUseCase = errorHandlingUseCase
    }
    
    func setSyncControl(_ syncControl: SyncControl) {
        self.syncControl = syncControl
    }

    // Skip migration use case removed
    
    // MARK: - Authentication Actions
    
    func signInWithApple() async {
        isLoading = true
        clearErrors()
        
        do {
            let authResult = try await authenticateUserUseCase.signInWithApple()
            currentUser = authResult.user
            finalizeAuthentication(with: authResult.user)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func signOut() async {
        isLoading = true
        
        do {
            try await authenticateUserUseCase.signOut()
            authState = .unauthenticated
            currentUser = nil
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func clearErrors() {
        showError = false
        errorMessage = ""
        errorMessage = ""
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) {
        let context = ErrorContextHelper.createAuthenticationContext(operation: "Authentication")
        let result = errorHandlingUseCase.handleError(error, context: context)
        errorMessage = result.userMessage
        showError = true
        
        // Map the error to AuthError if it's an AuthError
        if let authError = error as? AuthError {
            authState = .error(authError)
        } else {
            // For other errors, create a generic AuthError
            authState = .error(.unknown(result.userMessage))
        }
    }
    
    // MARK: - Helpers (post-login)
    private func finalizeAuthentication(with user: User) {
        authState = .authenticated(user)
        if syncControl?.isBlocked == true {
            syncControl?.isBlocked = false
        }
    }
} 
