//
//  ProfileView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @StateObject private var viewModel: ProfileViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencyContainer) private var container
    
    init(viewModel: ProfileViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            List {
                // Profile Section
                profileSection
                
                // Preferences Section
                preferencesSection
                
                // Data Management Section
                dataManagementSection
                
                // Authentication Section
                authenticationSection
                
                // App Info Section
                appInfoSection
            }
            .navigationTitle("Profile")
            .refreshable {
                await viewModel.loadUserProfile()
            }
        }
        .sheet(isPresented: $viewModel.showAuthenticationView) {
            AuthenticationView.makeWithDependencies(
                container: container,
                modelContext: modelContext,
                onAuthenticationSuccess: {
                    // Dismiss the sheet when authentication is successful
                    viewModel.showAuthenticationView = false
                    // Reload user profile to reflect the new authenticated state
                    Task {
                        await viewModel.loadUserProfile()
                    }
                }
            )
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.clearErrors()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Confirm Sign Out", isPresented: $viewModel.showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                Task {
                    await viewModel.signOut()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .task {
            await viewModel.loadUserProfile()
        }
    }
    
    @ViewBuilder
    private var profileSection: some View {
        Section {
            HStack(spacing: 16) {
                // Profile Avatar
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(viewModel.currentUser?.authProvider.color ?? .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    if let user = viewModel.currentUser {
                        // Display name
                        Text(user.displayNameOrFallback)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        // Email (only for authenticated users)
                        if !user.isGuest, let email = user.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if user.isGuest {
                            Text("Local data only")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        // Auth provider badge
                        Text(user.authProvider.displayText)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(user.authProvider.color.opacity(0.2))
                            .foregroundColor(user.authProvider.color)
                            .cornerRadius(4)
                    } else {
                        // Loading state while user is being loaded
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Loading...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text("Please wait")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Show sign in button only for guest users
                if let user = viewModel.currentUser, user.isGuest {
                    Button("Sign In") {
                        viewModel.showAuthenticationView = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    @ViewBuilder
    private var preferencesSection: some View {
        Section("Preferences") {
            // Theme Preference
            HStack {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.purple)
                    .frame(width: 20)
                
                Picker("Theme", selection: $viewModel.selectedTheme) {
                    ForEach(ThemePreference.allCases, id: \.self) { theme in
                        Text(theme.displayText).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedTheme) { _, newTheme in
                    Task {
                        await viewModel.updateThemePreference(newTheme)
                    }
                }
            }
            
            // Units Preference
            HStack {
                Image(systemName: "ruler.fill")
                    .foregroundColor(.orange)
                    .frame(width: 20)
                
                Picker("Units", selection: $viewModel.selectedUnits) {
                    ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                        Text(unit.displayText).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedUnits) { _, newUnits in
                    Task {
                        await viewModel.updateUnitsPreference(newUnits)
                    }
                }
            }
            
            // Notifications Toggle
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(.red)
                    .frame(width: 20)
                
                Text("Notifications")
                
                Spacer()
                
                Toggle("", isOn: $viewModel.notificationsEnabled)
                    .onChange(of: viewModel.notificationsEnabled) { _, enabled in
                        Task {
                            await viewModel.updateNotificationPreference(enabled)
                        }
                    }
            }
            
            // Sync Toggle (only for authenticated users)
            if viewModel.currentUser?.authProvider != .guest {
                HStack {
                    Image(systemName: "icloud.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text("Sync Data")
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.syncEnabled)
                        .onChange(of: viewModel.syncEnabled) { _, enabled in
                            Task {
                                await viewModel.updateSyncPreference(enabled)
                            }
                        }
                }
            }
        }
    }
    
    @ViewBuilder
    private var dataManagementSection: some View {
        Section("Data Management") {
            // Export Data
            HStack {
                Image(systemName: "square.and.arrow.up.fill")
                    .foregroundColor(.green)
                    .frame(width: 20)
                
                Button("Export Data") {
                    Task {
                        await viewModel.exportUserData()
                    }
                }
                .foregroundColor(.primary)
                
                Spacer()
                
                if viewModel.isExporting {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .disabled(viewModel.isExporting)
            
            // Upgrade to Account (for guest users)
            if viewModel.currentUser?.authProvider == .guest {
                HStack {
                    Image(systemName: "person.badge.plus.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Button("Create Account") {
                        viewModel.showAuthenticationView = true
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private var authenticationSection: some View {
        if let user = viewModel.currentUser {
            Section("Account") {
                if user.authProvider == .guest {
                    HStack {
                        Image(systemName: "person.fill.questionmark")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        Button("Sign In to Sync Data") {
                            viewModel.showAuthenticationView = true
                        }
                        .foregroundColor(.blue)
                        
                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .foregroundColor(.red)
                            .frame(width: 20)
                        
                        Button("Sign Out") {
                            viewModel.showSignOutConfirmation = true
                        }
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var appInfoSection: some View {
        Section("About") {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.gray)
                    .frame(width: 20)
                
                Text("App Version")
                
                Spacer()
                
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text("Support")
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Extensions for UI

// Display properties are now defined directly in the enum types in User.swift

#Preview {
    let modelContainer = try! ModelContainer(for: User.self, PeeEvent.self)
    let container = DependencyContainer()
    
    ProfileView(viewModel: container.makeProfileViewModel(modelContext: modelContainer.mainContext))
        .environment(\.dependencyContainer, container)
        .modelContainer(modelContainer)
} 
