//
//  ProfileViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Use Cases
    private let authenticateUserUseCase: AuthenticateUserUseCaseProtocol
    private let createUserProfileUseCase: CreateUserProfileUseCaseProtocol
    private let updateUserPreferencesUseCase: UpdateUserPreferencesUseCaseProtocol
    private let userRepository: UserRepository
    private let peeEventRepository: PeeEventRepository
    private let syncCoordinator: SyncCoordinator
    private let errorHandlingUseCase: ErrorHandlingUseCase
    
    // MARK: - Published Properties
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage = ""
    @Published var syncStatus: SyncStatus = .idle
    
    // MARK: - Profile Editing
    @Published var isEditingProfile = false
    @Published var editedDisplayName = ""
    @Published var editedEmail = ""
    
    // MARK: - Preferences
    @Published var notificationsEnabled = true
    @Published var selectedUnits: MeasurementUnit = .metric
    @Published var selectedTheme: ThemePreference = .system
    @Published var syncEnabled = true
    
    // MARK: - Settings States
    @Published var showDeleteAccountAlert = false
    @Published var showSignOutAlert = false
    @Published var showSignOutConfirmation = false
    @Published var showAuthenticationView = false
    @Published var showDataExportSheet = false
    @Published var exportedData: Data?
    @Published var isExporting = false
    
    // MARK: - Internal State
    private var isSigningOut = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        authenticateUserUseCase: AuthenticateUserUseCaseProtocol,
        createUserProfileUseCase: CreateUserProfileUseCaseProtocol,
        updateUserPreferencesUseCase: UpdateUserPreferencesUseCaseProtocol,
        userRepository: UserRepository,
        errorHandlingUseCase: ErrorHandlingUseCase,
        peeEventRepository: PeeEventRepository,
        syncCoordinator: SyncCoordinator
    ) {
        self.authenticateUserUseCase = authenticateUserUseCase
        self.createUserProfileUseCase = createUserProfileUseCase
        self.updateUserPreferencesUseCase = updateUserPreferencesUseCase
        self.userRepository = userRepository
        self.errorHandlingUseCase = errorHandlingUseCase
        self.peeEventRepository = peeEventRepository
        self.syncCoordinator = syncCoordinator
        
        setupObservers()
        loadUserData()
    }
    
    // MARK: - Theme Management
    
    private func updateAppTheme() {
        // Theme is updated via UserDefaults which triggers app-level theme change
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "selectedTheme")
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe user repository changes
        userRepository.currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self = self else { return }
                
                // Don't process repository updates during sign-out to prevent race conditions
                guard !self.isSigningOut else { return }
                
                // During normal operation, we want to be careful about updates
                // to prevent race conditions where old authenticated users reappear
                if let currentUser = self.currentUser {
                    // We have a current user - only update if:
                    // 1. The new user is different (by ID)
                    // 2. OR the new user is a guest and current user is authenticated (sign-out scenario)
                    // 3. OR the new user is authenticated and current user is guest (sign-in scenario)
                    let shouldUpdate = (currentUser.id != user?.id) ||
                                     (user?.isGuest == true && !currentUser.isGuest) ||
                                     (user?.isGuest == false && currentUser.isGuest)
                    
                    if shouldUpdate {
                        self.currentUser = user
                        self.updatePreferencesFromUser()
                    }
                } else {
                    // No current user - accept any user from repository
                    self.currentUser = user
                    self.updatePreferencesFromUser()
                }
            }
            .store(in: &cancellables)
        
        // Observe sync status
        userRepository.syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status
            }
            .store(in: &cancellables)
        
        // Observe repository loading state - but don't override manual loading states
        userRepository.isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] repositoryLoading in
                guard let self = self else { return }
                // Only update if we're not already in a loading state
                if !self.isLoading {
                    self.isLoading = repositoryLoading
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadUserData() {
        Task {
            do {
                let user = await userRepository.getCurrentUser()
                currentUser = user
                updatePreferencesFromUser()
            }
        }
    }
    
    private func updatePreferencesFromUser() {
        guard let user = currentUser else { return }
        
        let preferences = user.preferences
        notificationsEnabled = preferences.notificationsEnabled
        selectedUnits = preferences.units
        selectedTheme = preferences.theme
        // Sync is always on for authenticated users; keep UI field but don't expose toggle
        syncEnabled = true
    }
    
    // MARK: - Profile Management
    
    func startEditingProfile() {
        guard let user = currentUser else { return }
        
        editedDisplayName = user.displayName ?? ""
        editedEmail = user.email ?? ""
        isEditingProfile = true
    }
    
    func saveProfileChanges() async {
        guard let user = currentUser else { return }
        
        isLoading = true
        clearErrors()
        
        do {
            let updatedUser = try await createUserProfileUseCase.updateProfile(
                user: user,
                displayName: editedDisplayName.isEmpty ? nil : editedDisplayName,
                email: editedEmail.isEmpty ? nil : editedEmail
            )
            
            currentUser = updatedUser
            isEditingProfile = false
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    func cancelProfileEditing() {
        isEditingProfile = false
        editedDisplayName = ""
        editedEmail = ""
        clearErrors()
    }
    
    // MARK: - User Profile Loading
    
    func loadUserProfile() async {
        // Don't override repository state during sign-out
        guard !isSigningOut else { 
            return 
        }
        
        await MainActor.run {
            isLoading = true
            clearErrors()
        }
        
        let user = await userRepository.getCurrentUser()
        
        await MainActor.run {
            // If no user found, create a guest user
            if user == nil {
                Task {
                    do {
                        let guestUser = try await userRepository.createGuestUser()
                        await MainActor.run {
                            // Only update if we're not signing out
                            if !isSigningOut {
                                currentUser = guestUser
                                updatePreferencesFromUser()
                            }
                            isLoading = false
                        }
                    } catch {
                        await MainActor.run {
                            handleError(error)
                            isLoading = false
                        }
                    }
                }
            } else {
                // Only update current user if not signing out and it's actually different
                if !isSigningOut && currentUser?.id != user?.id {
                    currentUser = user
                    updatePreferencesFromUser()
                }
                isLoading = false
            }
        }
    }
    
    // MARK: - Preferences Management (New Methods for ProfileView)
    
    func updateThemePreference(_ theme: ThemePreference) async {
        selectedTheme = theme
        
        // Update theme immediately in UserDefaults for app-level theme change
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
        
        // Update user preferences
        await updateTheme()
    }
    
    func updateUnitsPreference(_ units: MeasurementUnit) async {
        selectedUnits = units
        await updateUnits()
    }
    
    func updateNotificationPreference(_ enabled: Bool) async {
        notificationsEnabled = enabled
        await updateNotificationSettings()
    }
    
    func updateSyncPreference(_ enabled: Bool) async {
        syncEnabled = enabled
        await updateSyncSettings()
    }
    
    // MARK: - Preferences Management (Legacy Methods)
    
    func updateNotificationSettings() async {
        guard let user = currentUser else { return }
        
        do {
            _ = try await updateUserPreferencesUseCase.updateNotificationSettings(
                user: user,
                enabled: notificationsEnabled
            )
        } catch {
            handleError(error)
            // Revert on error
            notificationsEnabled = user.preferences.notificationsEnabled
        }
    }
    
    func updateUnits() async {
        guard let user = currentUser else { return }
        
        do {
            _ = try await updateUserPreferencesUseCase.updateUnits(
                user: user,
                units: selectedUnits
            )
        } catch {
            handleError(error)
            // Revert on error
            selectedUnits = user.preferences.units
        }
    }
    
    func updateTheme() async {
        guard let user = currentUser else { return }
        
        do {
            _ = try await updateUserPreferencesUseCase.updateTheme(
                user: user,
                theme: selectedTheme
            )
        } catch {
            handleError(error)
            // Revert on error
            selectedTheme = user.preferences.theme
        }
    }
    
    func updateSyncSettings() async {
        guard let user = currentUser else { return }
        
        do {
            _ = try await updateUserPreferencesUseCase.updateSyncSettings(
                user: user,
                syncEnabled: syncEnabled
            )
        } catch {
            handleError(error)
            // Revert on error
            syncEnabled = user.preferences.syncEnabled
        }
    }
    
    func resetPreferencesToDefaults() async {
        guard let user = currentUser else { return }
        
        isLoading = true
        clearErrors()
        
        do {
            _ = try await updateUserPreferencesUseCase.resetToDefaults(user: user)
            updatePreferencesFromUser()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Data Management
    
    func syncData() async {
        guard let user = currentUser, !user.isGuest else { return }
        
        do {
            try await userRepository.syncUserData()
        } catch {
            handleError(error)
        }
    }
    
    func exportUserData() async {
        isExporting = true
        isLoading = true
        clearErrors()
        
        do {
            let data = try await userRepository.exportUserData()
            exportedData = data
            showDataExportSheet = true
        } catch {
            handleError(error)
        }
        
        isLoading = false
        isExporting = false
    }
    
    // MARK: - Account Management
    
    func signOut() async {
        showSignOutConfirmation = false
        
        await MainActor.run {
            isSigningOut = true
            isLoading = true
            currentUser = nil
        }
        
        do {
            // Sync all data (events + profile) before sign out
            try? await syncCoordinator.syncBeforeLogout()
            
            // Sign out from Firebase
            try await authenticateUserUseCase.signOut()
            
            // Clear all authenticated users from local database with retry logic
            var attempts = 0
            let maxAttempts = 3
            
            while attempts < maxAttempts {
                do {
                    try await userRepository.clearAuthenticatedUsers()
                    break // Success, exit the retry loop
                } catch {
                    attempts += 1
                    if attempts == maxAttempts {
                        throw error // Rethrow if all attempts failed
                    }
                    // Wait a bit before retrying
                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
                }
            }
            
            // Small delay to ensure clearing is complete
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Clear all local events as part of logout transition
            do { try peeEventRepository.clearAllEvents() } catch { /* no-op */ }

            // Create a fresh guest user
            let guestUser = try await userRepository.createGuestUser()
            await MainActor.run {
                currentUser = guestUser
                updatePreferencesFromUser()
            }
        } catch {
            // If sign out fails, still try to create a guest user
            do {
                let guestUser = try await userRepository.createGuestUser()
                await MainActor.run {
                    currentUser = guestUser
                    updatePreferencesFromUser()
                }
            } catch {
                handleError(error)
            }
        }
        
        await MainActor.run {
            isSigningOut = false
            isLoading = false
        }
    }
    
    func deleteAccount() async {
        isLoading = true
        
        do {
            try await authenticateUserUseCase.deleteAccount()
            
            // Create a guest user immediately after deleting account
            // to avoid showing confusing "Not signed in" state
            let guestUser = User.createGuest()
            try await userRepository.saveUser(guestUser)
            currentUser = guestUser
            updatePreferencesFromUser()
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    // MARK: - Computed Properties
    
    var userDisplayName: String {
        currentUser?.displayNameOrFallback ?? "User"
    }
    
    var userInitials: String {
        currentUser?.initials ?? "U"
    }
    
    var userEmail: String? {
        currentUser?.email
    }
    
    var isGuestUser: Bool {
        currentUser?.isGuest ?? false
    }
    
    var authProviderDisplayName: String {
        currentUser?.authProvider.displayText ?? "Unknown"
    }
    
    var accountCreatedDate: String {
        guard let user = currentUser else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: user.createdAt)
    }
    
    var canSync: Bool {
        guard let user = currentUser else { return false }
        return !user.isGuest && user.preferences.syncEnabled
    }
    
    var syncStatusText: String {
        switch syncStatus {
        case .idle:
            return "Ready to sync"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return "Sync error: \(message)"
        }
    }
    
    var syncStatusColor: Color {
        switch syncStatus {
        case .idle:
            return .gray
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) {
        let context = ErrorContextHelper.createProfileContext()
        let result = errorHandlingUseCase.handleError(error, context: context)
        errorMessage = result.userMessage
        showError = true
    }
    
    func clearErrors() {
        showError = false
        errorMessage = ""
    }
    
    // MARK: - Validation
    
    var isProfileFormValid: Bool {
        !editedDisplayName.isEmpty || !editedEmail.isEmpty
    }
    
    func validateEmail(_ email: String) -> Bool {
        return authenticateUserUseCase.isEmailValid(email)
    }
} 
 