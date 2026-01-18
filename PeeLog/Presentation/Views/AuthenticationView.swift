//
//  AuthenticationView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData

struct AuthenticationView: View {
    @StateObject private var viewModel: AuthenticationViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencyContainer) private var container
    
    // Callback for when authentication is successful
    private let onAuthenticationSuccess: (() -> Void)?
    
    init(viewModel: AuthenticationViewModel, onAuthenticationSuccess: (() -> Void)? = nil) {
        self.onAuthenticationSuccess = onAuthenticationSuccess
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.1)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App Logo/Header
                        VStack(spacing: 16) {
                            Image(systemName: "drop.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            Text("Welcome to PeeLog")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text("Track your hydration health")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 40)
                        
                        // Authentication Form
                        VStack(spacing: 20) {
                            appleSignInButton
                            
                            dividerWithText
                            
                            authenticationForm
                            
                            Divider()
                                .padding(.vertical, 10)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 32)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        .padding(.horizontal, 20)
                        
                        Spacer()
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .onChange(of: viewModel.authState) { _, newState in
            // Check if authentication was successful
            switch newState {
            case .authenticated:
                onAuthenticationSuccess?()
            default:
                break
            }
        }
        .sheet(isPresented: $viewModel.showForgotPassword) {
            forgotPasswordSheet
        }
        .sheet(isPresented: $viewModel.showEmailVerification) {
            emailVerificationSheet
        }
        .interactiveDismissDisabled(viewModel.isLoading)
        .appAlert(
            isPresented: $viewModel.showError,
            title: "Something went wrong",
            message: viewModel.errorMessage,
            iconSystemName: "exclamationmark.triangle.fill",
            primaryTitle: "OK"
        )
        // Legacy migration removed

    }
    
    // MARK: - Forgot Password Sheet
    
    @ViewBuilder
    private var forgotPasswordSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Reset Password")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Email Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Email Address", text: $viewModel.forgotPasswordEmail)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    if !viewModel.forgotPasswordMessage.isEmpty {
                        Text(viewModel.forgotPasswordMessage)
                            .font(.caption)
                            .foregroundColor(viewModel.showForgotPasswordSuccess ? .green : .red)
                    }
                }
                .padding(.horizontal)
                
                // Send Reset Button
                Button(action: {
                    Task {
                        await viewModel.sendPasswordReset()
                    }
                }) {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text("Send Reset Email")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.forgotPasswordEmail.isEmpty ? Color.gray : Color.blue)
                    .cornerRadius(10)
                }
                .disabled(viewModel.forgotPasswordEmail.isEmpty || viewModel.isLoading)
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Forgot Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        viewModel.resetForgotPasswordForm()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Email Verification Sheet
    
    @ViewBuilder
    private var emailVerificationSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "envelope.badge.checkmark.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Verify Your Email")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("We've sent a verification email to:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text(viewModel.verificationEmail)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Instructions
                VStack(spacing: 16) {
                    Text("Please check your email and click the verification link to complete your account setup.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    if !viewModel.verificationMessage.isEmpty {
                        Text(viewModel.verificationMessage)
                            .font(.caption)
                            .foregroundColor(viewModel.verificationMessage.contains("successfully") ? .green : .red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 16) {
                    // Check Verification Status Button
                    Button(action: {
                        Task {
                            await viewModel.checkEmailVerificationStatus()
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text("I've Verified My Email")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal)
                    
                    // Resend Verification Button
                    Button(action: {
                        Task {
                            await viewModel.resendVerificationEmail()
                        }
                    }) {
                        HStack {
                            if viewModel.isResendingVerification {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(0.8)
                            }
                            Text(viewModel.canResendVerification ? "Resend Verification Email" : "Resend in \(viewModel.resendCountdown)s")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .disabled(!viewModel.canResendVerification || viewModel.isResendingVerification)
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .navigationTitle("Email Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        viewModel.resetEmailVerificationForm()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    @ViewBuilder
    private var appleSignInButton: some View {
        Button(action: {
            Task {
                await viewModel.signInWithApple()
            }
        }) {
            HStack {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
                Text("Continue with Apple")
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(viewModel.isLoading)
    }
    
    @ViewBuilder
    private var dividerWithText: some View {
        HStack {
            VStack {
                Divider()
            }
            Text("or")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
            VStack {
                Divider()
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var authenticationForm: some View {
        VStack(spacing: 16) {
            // Mode Toggle
            Picker("Mode", selection: $viewModel.isLoginMode) {
                Text("Sign In").tag(true)
                Text("Sign Up").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.bottom, 8)
            
            // Email Field
            VStack(alignment: .leading, spacing: 4) {
                TextField("Email", text: $viewModel.email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if let emailError = viewModel.emailError {
                    Text(emailError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 4) {
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if let passwordError = viewModel.passwordError {
                    Text(passwordError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            // Confirm Password (for registration)
            if !viewModel.isLoginMode {
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if viewModel.password != viewModel.confirmPassword && !viewModel.confirmPassword.isEmpty {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                // Display Name (for registration)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Display Name (Optional)", text: $viewModel.displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if let displayNameError = viewModel.displayNameError {
                        Text(displayNameError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Submit Button
            Button(action: {
                Task {
                    if viewModel.isLoginMode {
                        await viewModel.signInWithEmail()
                    } else {
                        await viewModel.registerWithEmail()
                    }
                }
            }) {
                Text(viewModel.buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(viewModel.isFormValid ? Color.blue : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
            
            // Forgot Password Button (only in login mode)
            if viewModel.isLoginMode {
                Button("Forgot Password?") {
                    viewModel.showForgotPassword = true
                }
                .font(.footnote)
                .foregroundColor(.blue)
                .padding(.top, 8)
            }
            
            // Mode Toggle Text
            Button(viewModel.toggleModeText) {
                viewModel.toggleMode()
            }
            .font(.footnote)
            .foregroundColor(.blue)
        }
    }
}

// MARK: - Dependency Injection Helper

extension AuthenticationView {
    static func makeWithDependencies(
        container: DependencyContainer, 
        modelContext: ModelContext,
        onAuthenticationSuccess: (() -> Void)? = nil
    ) -> AuthenticationView {
        let viewModel = container.makeAuthenticationViewModel(modelContext: modelContext)
        return AuthenticationView(viewModel: viewModel, onAuthenticationSuccess: onAuthenticationSuccess)
    }
}

#Preview {
    let modelContainer = try! ModelContainer(for: User.self)
    let container = DependencyContainer()
    
    return AuthenticationView(viewModel: container.makeAuthenticationViewModel(modelContext: modelContainer.mainContext))
        .environment(\.dependencyContainer, container)
        .modelContainer(modelContainer)
} 
