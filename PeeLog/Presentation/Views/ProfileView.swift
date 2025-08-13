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
    @Environment(\.colorScheme) private var colorScheme
    
    // Animated gradient phase (0...1) for full-length border stroke
    @State private var gradientPhase: Double = 0
    
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
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .appAlert(
            isPresented: $viewModel.showError,
            title: "Something went wrong",
            message: viewModel.errorMessage,
            iconSystemName: "exclamationmark.triangle.fill",
            primaryTitle: "OK",
            onPrimary: { viewModel.clearErrors() }
        )
        .appConfirm(
            isPresented: $viewModel.showSignOutConfirmation,
            title: "Confirm Sign Out",
            message: "Are you sure you want to sign out?",
            iconSystemName: "rectangle.portrait.and.arrow.right.fill",
            primaryTitle: "Sign Out",
            primaryDestructive: true,
            onPrimary: { Task { await viewModel.signOut() } },
            secondaryTitle: "Cancel",
            secondaryDestructive: false,
            onSecondary: { }
        )
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
            
            // Sync always-on for authenticated users; no toggle shown
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
        }
    }
    
    @ViewBuilder
    private var authenticationSection: some View {
        if let user = viewModel.currentUser {
            Section("Account") {
				if user.authProvider == .guest {
					Button(action: { viewModel.showAuthenticationView = true }) {
						HStack {
							Image(systemName: "person.fill.questionmark")
								.foregroundColor(.orange)
								.frame(width: 20)
							Text("Sign In or Create Account")
								.foregroundColor(.blue)
								.fontWeight(.semibold)
							Spacer()
						}
					}
					.buttonStyle(.plain)
					.frame(maxWidth: .infinity, alignment: .leading)
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
					.listRowBackground(
						ZStack {
							let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
							shape.fill(Color(.secondarySystemGroupedBackground))
							// Subtle base border
							shape.strokeBorder(Color.accentColor.opacity(0.12), lineWidth: 1)

							// Full-length gradient stroke with animated phase (sweeps around)
                            shape.strokeBorder(
                                ctaGradient(phase: gradientPhase, colorScheme: colorScheme),
                                lineWidth: 3
                            )
							.animation(.linear(duration: 1.6).repeatCount(2, autoreverses: false), value: gradientPhase)
						}
						.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
					)
					.onAppear {
						gradientPhase = 0
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
							gradientPhase = 1
						}
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

// MARK: - Gradient Helpers
private extension ProfileView {
	func ctaGradient(phase: Double, colorScheme: ColorScheme) -> AngularGradient {
		let stops: [Gradient.Stop]
		if colorScheme == .dark {
			// Richer, slightly more saturated sweep for dark mode
			stops = [
				.init(color: .cyan.opacity(0.70),   location: 0.00),
				.init(color: .blue.opacity(0.90),   location: 0.20),
				.init(color: .indigo,               location: 0.50),
				.init(color: .purple.opacity(0.90), location: 0.80),
				.init(color: .cyan.opacity(0.70),   location: 1.00)
			]
		} else {
			// Softer, balanced sweep for light mode (avoids overpowering on light bg)
			stops = [
				.init(color: .blue.opacity(0.45),   location: 0.00),
				.init(color: .teal.opacity(0.55),   location: 0.20),
				.init(color: .indigo.opacity(0.70), location: 0.50),
				.init(color: .purple.opacity(0.55), location: 0.80),
				.init(color: .blue.opacity(0.45),   location: 1.00)
			]
		}
		return AngularGradient(
			gradient: Gradient(stops: stops),
			center: .center,
			startAngle: .degrees(phase * 360),
			endAngle: .degrees(phase * 360 + 360)
		)
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
 
