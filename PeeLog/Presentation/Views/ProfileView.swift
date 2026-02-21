//
//  ProfileView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData
import UIKit
import WebKit

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
        NavigationStack {
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
        .sheet(isPresented: $viewModel.showDataExportSheet) {
            if let url = viewModel.exportFileURL {
                ShareSheet(activityItems: [url])
            } else {
                Text("Unable to prepare export file.")
            }
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
                        // Display name (only show if provided by Apple)
                        if let name = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !name.isEmpty {
                            Text(name)
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        
                        // Email (if available)
                        if let email = user.email {
                            Text(email)
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
            
            // TODO: Re-enable and enhance push notifications in next release
            // Notifications Toggle
//            HStack {
//                Image(systemName: "bell.fill")
//                    .foregroundColor(.red)
//                    .frame(width: 20)
//                
//                Text("Notifications")
//                
//                Spacer()
//                
//                Toggle("", isOn: $viewModel.notificationsEnabled)
//                    .onChange(of: viewModel.notificationsEnabled) { _, enabled in
//                        Task {
//                            await viewModel.updateNotificationPreference(enabled)
//                        }
//                    }
//            }
            
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
            
            Button {
                if let url = URL(string: "mailto:support@peelog.app") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    Text("Support")
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            
            NavigationLink(destination: SafariWebView(url: URL(string: "https://peelog.app/privacy")!, title: "Privacy Policy")) {
                HStack {
                    Image(systemName: "hand.raised.fill")
                        .foregroundColor(.indigo)
                        .frame(width: 20)
                    Text("Privacy Policy")
                }
            }
            
            NavigationLink(destination: SafariWebView(url: URL(string: "https://peelog.app/terms")!, title: "Terms of Use")) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.orange)
                        .frame(width: 20)
                    Text("Terms of Use")
                }
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

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - WebView Components
struct WebView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .systemBackground
        webView.isOpaque = false 
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Only load if url changed to avoid reload loop
        if uiView.url?.absoluteString != url.absoluteString {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
}

struct SafariWebView: View {
    let url: URL
    let title: String
    
    var body: some View {
        WebView(url: url)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }
}
 
