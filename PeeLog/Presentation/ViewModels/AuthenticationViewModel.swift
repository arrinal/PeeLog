//
//  AuthenticationViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthenticationViewModel: ObservableObject {
    // MARK: - Use Cases
    private let authenticateUserUseCase: AuthenticateUserUseCaseProtocol
    private let createUserProfileUseCase: CreateUserProfileUseCaseProtocol
    private let errorHandlingUseCase: ErrorHandlingUseCase
    private var syncControl: SyncControl?
    
    // MARK: - Published Properties
    @Published var authState: AuthState = .unauthenticated
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    
    // MARK: - Form Properties
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var displayName = ""
    @Published var isLoginMode = true
    
    // MARK: - Forgot Password
    @Published var showForgotPassword = false
    @Published var forgotPasswordEmail = ""
    @Published var showForgotPasswordSuccess = false
    @Published var forgotPasswordMessage = ""
    
    // MARK: - Email Verification
    @Published var showEmailVerification = false
    @Published var verificationEmail = ""
    @Published var verificationMessage = ""
    @Published var isResendingVerification = false
    @Published var canResendVerification = true
    @Published var resendCountdown = 0
    private var temporaryPassword = "" // Store password temporarily for auto-login after verification
    
    // MARK: - Validation Properties
    @Published var emailError: String?
    @Published var passwordError: String?
    @Published var displayNameError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authenticateUserUseCase: AuthenticateUserUseCaseProtocol,
        createUserProfileUseCase: CreateUserProfileUseCaseProtocol,
        errorHandlingUseCase: ErrorHandlingUseCase
    ) {
        self.authenticateUserUseCase = authenticateUserUseCase
        self.createUserProfileUseCase = createUserProfileUseCase
        self.errorHandlingUseCase = errorHandlingUseCase
        
        setupValidation()
    }
    
    func setSyncControl(_ syncControl: SyncControl) {
        self.syncControl = syncControl
    }

    // Skip migration use case removed
    
    // MARK: - Validation Setup
    
    private func setupValidation() {
        // Email validation
        $email
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] email in
                self?.validateEmail(email)
            }
            .store(in: &cancellables)
        
        // Password validation
        $password
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] password in
                self?.validatePassword(password)
            }
            .store(in: &cancellables)
        
        // Display name validation (only for registration)
        $displayName
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] displayName in
                if !(self?.isLoginMode ?? true) {
                    self?.validateDisplayName(displayName)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Actions
    
    func signInWithEmail() async {
        guard validateForm() else { return }
        
        isLoading = true
        clearErrors()
        
        do {
            let authResult = try await authenticateUserUseCase.signInWithEmail(email, password: password)
            currentUser = authResult.user
            clearForm()
            finalizeAuthentication(with: authResult.user)
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func registerWithEmail() async {
        guard validateForm() else { return }
        
        isLoading = true
        clearErrors()
        
        do {
            let _ = try await authenticateUserUseCase.registerWithEmail(
                email,
                password: password,
                displayName: displayName.isEmpty ? nil : displayName
            )
            
            // Don't authenticate the user yet - show verification UI instead
            verificationEmail = email
            temporaryPassword = password // Store password temporarily for auto-login after verification
            verificationMessage = ""
            showEmailVerification = true
            startResendCooldown()
            
            // Clear form but don't update auth state
            clearForm()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
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
            clearForm()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Password Reset
    
    func sendPasswordReset() async {
        guard !forgotPasswordEmail.isEmpty else {
            forgotPasswordMessage = "Please enter your email address"
            return
        }
        
        guard authenticateUserUseCase.isEmailValid(forgotPasswordEmail) else {
            forgotPasswordMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        forgotPasswordMessage = ""
        
        do {
            try await authenticateUserUseCase.sendPasswordReset(toEmail: forgotPasswordEmail)
            showForgotPasswordSuccess = true
            forgotPasswordMessage = "Password reset email sent! Check your inbox."
        } catch {
            forgotPasswordMessage = "Failed to send reset email. Please try again."
        }
        
        isLoading = false
    }
    
    func resetForgotPasswordForm() {
        forgotPasswordEmail = ""
        forgotPasswordMessage = ""
        showForgotPasswordSuccess = false
        showForgotPassword = false
    }
    
    // MARK: - Email Verification
    
    func resendVerificationEmail() async {
        guard canResendVerification && !isResendingVerification else { return }
        
        isResendingVerification = true
        verificationMessage = ""
        
        do {
            try await authenticateUserUseCase.sendEmailVerification(toEmail: verificationEmail, password: temporaryPassword)
            verificationMessage = "Verification email resent successfully! Please check your email."
            startResendCooldown()
        } catch {
            verificationMessage = "Failed to resend verification email. Please try again."
        }
        
        isResendingVerification = false
    }
    
    func checkEmailVerificationStatus() async {
        do {
            let isVerified = try await authenticateUserUseCase.checkEmailVerificationStatus(email: verificationEmail, password: temporaryPassword)
            if isVerified {
                // User is verified, proceed to sign in
                await signInAfterVerification()
            } else {
                verificationMessage = "Email not verified yet. Please check your email and click the verification link."
            }
        } catch {
            verificationMessage = "Failed to check verification status. Please try again."
        }
    }
    
    private func signInAfterVerification() async {
        // Sign in the user after email verification
        do {
            let authResult = try await authenticateUserUseCase.signInWithEmail(verificationEmail, password: temporaryPassword)
            currentUser = authResult.user
            showEmailVerification = false
            finalizeAuthentication(with: authResult.user)
            resetEmailVerificationForm()
        } catch {
            verificationMessage = "Failed to sign in after verification. Please try signing in manually."
        }
    }
    
    private func startResendCooldown() {
        canResendVerification = false
        resendCountdown = 60 // 60 seconds cooldown
        
        Task { @MainActor in
            while resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                resendCountdown -= 1
            }
            canResendVerification = true
        }
    }
    
    func resetEmailVerificationForm() {
        verificationEmail = ""
        verificationMessage = ""
        isResendingVerification = false
        canResendVerification = true
        resendCountdown = 0
        showEmailVerification = false
        temporaryPassword = "" // Clear temporary password for security
    }
    
    // MARK: - Form Management
    
    func toggleMode() {
        isLoginMode.toggle()
        clearErrors()
        clearForm()
    }
    
    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
    }
    
    func clearErrors() {
        showError = false
        errorMessage = ""
        emailError = nil
        passwordError = nil
        displayNameError = nil
    }
    
    // MARK: - Validation
    
    private func validateForm() -> Bool {
        var isValid = true
        
        if !authenticateUserUseCase.isEmailValid(email) {
            emailError = "Please enter a valid email address"
            isValid = false
        }
        
        if !authenticateUserUseCase.isPasswordValid(password) {
            passwordError = "Password must be at least 6 characters long"
            isValid = false
        }
        
        if !isLoginMode && password != confirmPassword {
            passwordError = "Passwords do not match"
            isValid = false
        }
        
        return isValid
    }
    
    private func validateEmail(_ email: String) {
        if email.isEmpty {
            emailError = nil
        } else if !authenticateUserUseCase.isEmailValid(email) {
            emailError = "Please enter a valid email address"
        } else {
            emailError = nil
        }
    }
    
    private func validatePassword(_ password: String) {
        if password.isEmpty {
            passwordError = nil
        } else if !authenticateUserUseCase.isPasswordValid(password) {
            passwordError = "Password must be at least 6 characters long"
        } else {
            passwordError = nil
        }
    }
    
    private func validateDisplayName(_ displayName: String) {
        if displayName.isEmpty {
            displayNameError = nil
        } else if displayName.count < 2 {
            displayNameError = "Display name must be at least 2 characters long"
        } else {
            displayNameError = nil
        }
    }
    
    // MARK: - Computed Properties
    
    var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        emailError == nil &&
        passwordError == nil &&
        (isLoginMode || password == confirmPassword)
    }
    
    var buttonTitle: String {
        if isLoading {
            return "Please wait..."
        }
        return isLoginMode ? "Sign In" : "Create Account"
    }
    
    var toggleModeText: String {
        isLoginMode ? "Don't have an account? Sign up" : "Already have an account? Sign in"
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) {
        // Check if this is an email not verified error
        if let authError = error as? AuthError, authError == .emailNotVerified {
            // Show email verification UI instead of error
            verificationEmail = email
            temporaryPassword = password // Store password temporarily for auto-login after verification
            verificationMessage = ""
            showEmailVerification = true
            startResendCooldown()
            return
        }
        
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
            NotificationCenter.default.post(name: .requestInitialFullSync, object: nil)
        }
    }
} 
