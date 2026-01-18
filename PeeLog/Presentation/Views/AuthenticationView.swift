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
                        
                        VStack(spacing: 20) {
                            appleSignInButton
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
