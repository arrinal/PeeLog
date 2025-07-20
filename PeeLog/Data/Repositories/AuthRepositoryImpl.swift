//
//  AuthRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftData
import Combine
@preconcurrency import FirebaseAuth

@MainActor
final class AuthRepositoryImpl: AuthRepository {
    private let firebaseAuthService: FirebaseAuthService
    private let modelContext: ModelContext
    private var cancellables = Set<AnyCancellable>()
    
    // Subjects for publishing
    private let authStateSubject = CurrentValueSubject<AuthState, Never>(.unauthenticated)
    private let currentUserSubject = CurrentValueSubject<User?, Never>(nil)
    private let isAuthenticatedSubject = CurrentValueSubject<Bool, Never>(false)
    private let isLoadingSubject = CurrentValueSubject<Bool, Never>(false)
    
    // Flag to prevent Firebase auth observer interference during sign-out
    private var isSigningOut = false
    private var signOutCompletionTime: Date?
    
    init(firebaseAuthService: FirebaseAuthService, modelContext: ModelContext) {
        self.firebaseAuthService = firebaseAuthService
        self.modelContext = modelContext
        setupObservers()
        checkExistingAuthState()
    }
    
    // MARK: - Published Properties
    
    var authState: AnyPublisher<AuthState, Never> {
        authStateSubject.eraseToAnyPublisher()
    }
    
    var currentUser: AnyPublisher<User?, Never> {
        currentUserSubject.eraseToAnyPublisher()
    }
    
    var isAuthenticated: AnyPublisher<Bool, Never> {
        isAuthenticatedSubject.eraseToAnyPublisher()
    }
    
    var isLoading: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe Firebase auth state changes
        firebaseAuthService.$isSignedIn
            .sink { [weak self] isSignedIn in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if isSignedIn {
                        // Prevent handleFirebaseSignIn during sign-out to avoid race condition
                        if !self.isSigningOut {
                            await self.handleFirebaseSignIn()
                        }
                    } else {
                        await self.handleFirebaseSignOut()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update derived properties when auth state changes
        authStateSubject
            .sink { [weak self] state in
                self?.currentUserSubject.send(state.user)
                self?.isAuthenticatedSubject.send(state.isAuthenticated)
            }
            .store(in: &cancellables)
    }
    
    private func checkExistingAuthState() {
        Task {
                    // Check if there's a current Firebase user
        if firebaseAuthService.getCurrentUser() != nil {
            await handleFirebaseSignIn()
        } else {
                // Check for local guest user
                if let guestUser = await getLocalGuestUser() {
                    updateAuthState(.guest(guestUser))
                } else {
                    updateAuthState(.unauthenticated)
                }
            }
        }
    }
    
    private func handleFirebaseSignIn() async {
        // Prevent sign-in processing during sign-out to avoid race condition
        if isSigningOut {
            return
        }
        
        // Additional protection: check if we recently completed sign-out
        if let completionTime = signOutCompletionTime {
            let timeSinceSignOut = Date().timeIntervalSince(completionTime)
            if timeSinceSignOut < 1.0 { // 1 second grace period
                return
            }
        }
        
        guard let firebaseUser = firebaseAuthService.getCurrentUser() else { 
            return 
        }
        
        do {
            // Reload user to get fresh data including display name
            try await firebaseAuthService.reloadUser()
            
            // Get updated user info after reload
            let updatedFirebaseUser = firebaseAuthService.getCurrentUser() ?? firebaseUser
            
            // Try to find existing user in local storage (but not during sign-out)
            if let existingUser = await getUserByEmail(updatedFirebaseUser.email) {
                // Double-check that we're not signing out before authenticating with cached user
                if isSigningOut {
                    return
                }
                
                // Additional timestamp-based protection
                if let completionTime = signOutCompletionTime {
                    let timeSinceSignOut = Date().timeIntervalSince(completionTime)
                    if timeSinceSignOut < 1.0 {
                        return
                    }
                }
                
                // Update display name if it's different from Firebase
                if existingUser.displayName != updatedFirebaseUser.displayName {
                    existingUser.displayName = updatedFirebaseUser.displayName
                    try await updateUserLocally(existingUser)
                }
                updateAuthState(.authenticated(existingUser))
            } else {
                // Don't create new users during sign-out
                if isSigningOut {
                    return
                }
                
                // Additional timestamp-based protection
                if let completionTime = signOutCompletionTime {
                    let timeSinceSignOut = Date().timeIntervalSince(completionTime)
                    if timeSinceSignOut < 1.0 {
                        return
                    }
                }
                
                // Create new user from Firebase user
                // Check the Firebase provider info to determine the correct auth provider
                let user: User
                if updatedFirebaseUser.providerData.contains(where: { $0.providerID == "apple.com" }) {
                    // User signed in with Apple
                    user = User.createAppleUser(
                        appleUserId: updatedFirebaseUser.uid,
                        email: updatedFirebaseUser.email,
                        displayName: updatedFirebaseUser.displayName
                    )
                } else {
                    // User signed in with email/password
                    // Use the updated Firebase user with fresh display name
                    user = User.createEmailUser(
                        email: updatedFirebaseUser.email ?? "",
                        displayName: updatedFirebaseUser.displayName
                    )
                }
                
                try await saveUserLocally(user)
                updateAuthState(.authenticated(user))
            }
        } catch {
            updateAuthState(.error(.unknown(error.localizedDescription)))
        }
    }
    
    private func handleFirebaseSignOut() async {
        // Clear current user first
        currentUserSubject.send(nil)
        
        // Check for local guest user
        if let guestUser = await getLocalGuestUser() {
            updateAuthState(.guest(guestUser))
        } else {
            updateAuthState(.unauthenticated)
        }
    }
    
    // MARK: - Authentication Methods
    
    func signInWithEmail(_ email: String, password: String) async throws -> AuthResult {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            let firebaseUser = try await firebaseAuthService.signInWithEmail(email, password: password)
            
            // Reload user to get fresh data including display name
            try await firebaseAuthService.reloadUser()
            
            // Get updated user info after reload
            let updatedFirebaseUser = firebaseAuthService.getCurrentUser() ?? firebaseUser
            let accessToken = try await firebaseAuthService.getIDToken()
            
            // Get or create local user
            let user: User
            if let existingUser = await getUserByEmail(email) {
                // Update display name if it's different from Firebase
                if existingUser.displayName != updatedFirebaseUser.displayName {
                    existingUser.displayName = updatedFirebaseUser.displayName
                    try await updateUserLocally(existingUser)
                }
                user = existingUser
            } else {
                user = User.createEmailUser(
                    email: email,
                    displayName: updatedFirebaseUser.displayName
                )
                try await saveUserLocally(user)
            }
            
            updateAuthState(.authenticated(user))
            
            return AuthResult(
                user: user,
                accessToken: accessToken
            )
            
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error.localizedDescription)
            updateAuthState(.error(authError))
            throw authError
        }
    }
    
    func registerWithEmail(_ email: String, password: String, displayName: String?) async throws -> AuthResult {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            let firebaseUser = try await firebaseAuthService.createUserWithEmail(email, password: password)
            
            // Update Firebase profile if display name provided
            if let displayName = displayName, !displayName.isEmpty {
                try await firebaseAuthService.updateDisplayName(displayName)
                // Reload user to ensure the display name is properly set
                try await firebaseAuthService.reloadUser()
            }
            
            // Send email verification
            try await firebaseAuthService.sendEmailVerification(to: firebaseUser)
            
            // Sign out the user since they need to verify email first
            try await firebaseAuthService.signOut()
            
            // Create local user (but don't authenticate them yet)
            let user = User.createEmailUser(
                email: email,
                displayName: displayName
            )
            
            // Don't save locally or update auth state since user is not verified yet
            // Return empty token since user is not authenticated
            return AuthResult(
                user: user,
                accessToken: ""
            )
            
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error.localizedDescription)
            updateAuthState(.error(authError))
            throw authError
        }
    }
    
    func signInWithApple() async throws -> AuthResult {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            let firebaseUser = try await firebaseAuthService.signInWithApple()
            let accessToken = try await firebaseAuthService.getIDToken()
            
            // Get or create local user
            let user: User
            if let email = firebaseUser.email, let existingUser = await getUserByEmail(email) {
                // Update existing user with Apple provider info
                user = existingUser
                user.updateAuthProvider(.apple)
                user.appleUserId = firebaseUser.uid
                // Save the updated user to persist the auth provider change
                try await updateUserLocally(user)
            } else {
                // Create new user with Apple Sign In
                user = User.createAppleUser(
                    appleUserId: firebaseUser.uid,
                    email: firebaseUser.email,
                    displayName: firebaseUser.displayName
                )
                try await saveUserLocally(user)
            }
            
            updateAuthState(.authenticated(user))
            
            return AuthResult(
                user: user,
                accessToken: accessToken
            )
            
        } catch {
            let authError = error as? AuthError ?? AuthError.unknown(error.localizedDescription)
            updateAuthState(.error(authError))
            throw authError
        }
    }
    
    func signInAsGuest() async throws -> User {
        isLoadingSubject.send(true)
        defer { isLoadingSubject.send(false) }
        
        do {
            // Check if guest user already exists
            if let existingGuest = await getLocalGuestUser() {
                updateAuthState(.guest(existingGuest))
                return existingGuest
            }
            
            // Create new guest user
            let guestUser = User.createGuest()
            try await saveUserLocally(guestUser)
            
            updateAuthState(.guest(guestUser))
            return guestUser
            
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }
    
    func signOut() async throws {
        do {
            // Set flag to prevent Firebase observer interference
            isSigningOut = true
            
            // Clear the current user subject immediately
            currentUserSubject.send(nil)
            
            // Sign out from Firebase
            try await firebaseAuthService.signOut()
            
            // handleFirebaseSignOut will be called automatically via observer
            // and will set the correct auth state based on available users
            
            // Reset flag after a longer delay and set completion timestamp
            Task {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    self.isSigningOut = false
                    self.signOutCompletionTime = Date()
                }
            }
            
        } catch {
            // Reset flag on error
            isSigningOut = false
            signOutCompletionTime = Date()
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    func deleteAccount() async throws {
        guard let currentUser = currentUserSubject.value else {
            throw AuthError.userNotFound
        }
        
        do {
            // Delete from Firebase if not guest
            if !currentUser.isGuest {
                try await firebaseAuthService.deleteAccount()
            }
            
            // Delete from local storage
            try await deleteUserLocally(currentUser)
            
            updateAuthState(.unauthenticated)
            
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset(toEmail email: String) async throws {
        do {
            // Validate email format
            guard isEmailValid(email) else {
                throw AuthError.invalidEmail
            }
            
            // Send password reset email via Firebase
            try await firebaseAuthService.sendPasswordReset(toEmail: email)
            
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Email Verification
    
    func sendEmailVerification() async throws {
        do {
            try await firebaseAuthService.sendEmailVerification()
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    func sendEmailVerification(to user: User) async throws {
        do {
            // For local User object, we need to use the current Firebase user
            // Since we can't directly use our User object with Firebase methods
            try await firebaseAuthService.sendEmailVerification()
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    func sendEmailVerification(toEmail email: String, password: String) async throws {
        do {
            try await firebaseAuthService.sendEmailVerification(toEmail: email, password: password)
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    func isEmailVerified() -> Bool {
        return firebaseAuthService.isEmailVerified()
    }
    
    func checkEmailVerificationStatus() async throws -> Bool {
        do {
            return try await firebaseAuthService.checkEmailVerificationStatus()
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    func checkEmailVerificationStatus(email: String, password: String) async throws -> Bool {
        do {
            return try await firebaseAuthService.checkEmailVerificationStatus(email: email, password: password)
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    func reloadUser() async throws {
        do {
            try await firebaseAuthService.reloadUser()
        } catch {
            throw error as? AuthError ?? AuthError.unknown(error.localizedDescription)
        }
    }
    
    // MARK: - Token Management
    
    func refreshToken() async throws -> String {
        return try await firebaseAuthService.refreshToken()
    }
    
    func isTokenValid() async -> Bool {
        return await firebaseAuthService.isTokenValid()
    }
    
    func getValidToken() async throws -> String? {
        guard await isTokenValid() else {
            return try await refreshToken()
        }
        return try await firebaseAuthService.getIDToken()
    }
    
    // MARK: - Guest Data Migration
    
    func migrateGuestData(to authenticatedUser: User) async throws {
        // This will be handled by MigrateGuestDataUseCase
        // Just update the auth state here
        updateAuthState(.authenticated(authenticatedUser))
    }
    
    // MARK: - User State Management
    
    func getCurrentUser() async -> User? {
        return currentUserSubject.value
    }
    
    func updateAuthState(_ state: AuthState) {
        authStateSubject.send(state)
    }
    
    func isUserAuthenticated() async -> Bool {
        // Check if we have a current user (guest or authenticated)
        if let currentUser = currentUserSubject.value {
            // For guest users, they are considered "authenticated" for local purposes
            if currentUser.isGuest {
                return true
            }
            
            // For real users, check if Firebase session is still valid
            return await firebaseAuthService.isTokenValid()
        }
        
        // No user at all
        return false
    }
    
    // MARK: - Validation
    
    func isEmailValid(_ email: String) -> Bool {
        return ValidationUtility.isEmailValid(email)
    }
    
    func isPasswordValid(_ password: String) -> Bool {
        return ValidationUtility.isPasswordValid(password)
    }
    
    // MARK: - Local Storage Helpers
    
    private func saveUserLocally(_ user: User) async throws {
        do {
            modelContext.insert(user)
            try modelContext.save()
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    private func updateUserLocally(_ user: User) async throws {
        do {
            user.updatedAt = Date()
            try modelContext.save()
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    private func deleteUserLocally(_ user: User) async throws {
        do {
            modelContext.delete(user)
            try modelContext.save()
        } catch {
            throw UserRepositoryError.saveFailed(error.localizedDescription)
        }
    }
    
    private func getUserByEmail(_ email: String?) async -> User? {
        guard let email = email else { return nil }
        
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.email == email }
        )
        
        do {
            let users = try modelContext.fetch(descriptor)
            return users.first
        } catch {
            return nil
        }
    }
    
    private func getLocalGuestUser() async -> User? {
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