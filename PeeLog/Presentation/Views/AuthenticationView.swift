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
    
    init(onAuthenticationSuccess: (() -> Void)? = nil) {
        // Temporary initialization - will be replaced when called from ContentView
        self.onAuthenticationSuccess = onAuthenticationSuccess
        self._viewModel = StateObject(wrappedValue: AuthenticationViewModel(
            authenticateUserUseCase: AuthenticateUserUseCase(
                authRepository: AuthRepositoryImpl(
                    firebaseAuthService: FirebaseAuthService(),
                    modelContext: ModelContext(try! ModelContainer(for: User.self))
                ),
                userRepository: UserRepositoryImpl(modelContext: ModelContext(try! ModelContainer(for: User.self))),
                errorHandlingUseCase: ErrorHandlingUseCaseImpl()
            ),
            createUserProfileUseCase: CreateUserProfileUseCase(
                userRepository: UserRepositoryImpl(modelContext: ModelContext(try! ModelContainer(for: User.self))),
                errorHandlingUseCase: ErrorHandlingUseCaseImpl()
            ),
            migrateGuestDataUseCase: MigrateGuestDataUseCase(
                userRepository: UserRepositoryImpl(modelContext: ModelContext(try! ModelContainer(for: User.self))),
                peeEventRepository: PeeEventRepositoryImpl(modelContext: ModelContext(try! ModelContainer(for: PeeEvent.self))),
                errorHandlingUseCase: ErrorHandlingUseCaseImpl()
            ),
            errorHandlingUseCase: ErrorHandlingUseCaseImpl()
        ))
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
                            
                            guestModeButton
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
            case .authenticated, .guest:
                // Authentication successful, call the success callback
                onAuthenticationSuccess?()
            default:
                break
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearErrors()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Migrate Your Data?", isPresented: $viewModel.showGuestMigrationAlert) {
            Button("Migrate Data") {
                Task {
                    await viewModel.proceedWithMigration()
                }
            }
            Button("Skip Migration") {
                Task {
                    await viewModel.skipMigration()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.showGuestMigrationAlert = false
            }
        } message: {
            Text("You have existing guest data. Would you like to migrate it to your new account?")
        }
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
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(viewModel.buttonTitle)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isFormValid ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!viewModel.isFormValid || viewModel.isLoading)
            
            // Mode Toggle Text
            Button(viewModel.toggleModeText) {
                viewModel.toggleMode()
            }
            .font(.footnote)
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var guestModeButton: some View {
        VStack(spacing: 12) {
            Text("Try without signing up")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                Task {
                    await viewModel.signInAsGuest()
                }
            }) {
                HStack {
                    Image(systemName: "person.circle")
                    Text("Continue as Guest")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
            .disabled(viewModel.isLoading)
            
            Text("Note: Guest data can be migrated to an account later")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
        var view = AuthenticationView(onAuthenticationSuccess: onAuthenticationSuccess)
        view._viewModel = StateObject(wrappedValue: container.makeAuthenticationViewModel(modelContext: modelContext))
        return view
    }
}

#Preview {
    AuthenticationView()
} 