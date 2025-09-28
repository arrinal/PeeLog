//
//  ContentView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData
import Combine

struct ContentView: View {
    @Environment(\.dependencyContainer) private var container
    @Environment(\.modelContext) private var modelContext
    @State private var authState: AuthenticationState = .checking
    @State private var currentUser: User?
    @State private var cancellables = Set<AnyCancellable>()
    @State private var lastSyncedUserId: UUID?
    @State private var showOnlineToast = false
    @State private var wasOffline = false
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var serverToastMessage: String? = nil
    @State private var lastServerToastAt: Date = .distantPast
    
    var body: some View {
        Group {
            switch authState {
            case .checking:
                loadingView
            case .authenticated(let user):
                ZStack(alignment: .top) {
                    mainTabView
                    connectivityOverlay
                }
                    .onAppear {
                        currentUser = user
                        Task { @MainActor in
                            let sync = container.makeSyncCoordinator(modelContext: modelContext)
                            try? await sync.initialFullSync()
                        }
                    }
            case .unauthenticated:
                AuthenticationView.makeWithDependencies(
                    container: container,
                    modelContext: modelContext
                )
            }
        }
        .task {
            await checkAuthenticationState()
            setupAuthStateObserver()
            setupConnectivityObserver()
            NotificationCenter.default.addObserver(forName: .requestInitialFullSync, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    let sync = container.makeSyncCoordinator(modelContext: modelContext)
                    try? await sync.initialFullSync()
                }
            }
            NotificationCenter.default.addObserver(forName: .serverStatusToast, object: nil, queue: .main) { note in
                guard let msg = note.userInfo?["message"] as? String else { return }
                Task { @MainActor in
                    // Do not show server toasts for guest users
                    if let user = self.currentUser, user.isGuest {
                        return
                    }
                    if self.currentUser == nil {
                        let userRepository = container.makeUserRepository(modelContext: modelContext)
                        let user = await userRepository.getCurrentUser()
                        if let user, user.isGuest { return }
                        self.currentUser = user
                    }
                    // rate-limit to 3s between toasts
                    let now = Date()
                    if now.timeIntervalSince(lastServerToastAt) > 3 {
                        lastServerToastAt = now
                        serverToastMessage = msg
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        serverToastMessage = nil
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "drop.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("PeeLog")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ProgressView()
                    .scaleEffect(1.2)
            }
        }
    }
    
    @ViewBuilder
    private var mainTabView: some View {
        TabView {
            HomeView(viewModel: container.makeHomeViewModel(modelContext: modelContext))
                .tabItem {
                    Label("Home", systemImage: "drop.fill")
                }
            
            MapHistoryView(viewModel: container.makeMapHistoryViewModel(modelContext: modelContext))
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            
            StatisticsView(viewModel: container.makeStatisticsViewModel(modelContext: modelContext))
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
            
            ProfileView(viewModel: container.makeProfileViewModel(modelContext: modelContext))
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
    }
    
    private func setupAuthStateObserver() {
        let authRepository = container.makeAuthRepository(modelContext: modelContext)
        
        authRepository.authState
            .receive(on: DispatchQueue.main)
            .sink { state in
                switch state {
                case .authenticated(let user):
                    authState = .authenticated(user)
                    // Trigger full sync when transitioning to a non-guest authenticated user
                    if !user.isGuest && lastSyncedUserId != user.id {
                        lastSyncedUserId = user.id
                        Task { @MainActor in
                            let sync = container.makeSyncCoordinator(modelContext: modelContext)
                            try? await sync.initialFullSync()
                        }
                    }
                case .guest(let user):
                    authState = .authenticated(user)
                case .unauthenticated:
                    break
                case .error:
                    break
                case .authenticating:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkAuthenticationState() async {
        do {
            let authRepository = container.makeAuthRepository(modelContext: modelContext)
            let userRepository = container.makeUserRepository(modelContext: modelContext)
            
            // First check Firebase auth state
            let isFirebaseAuthenticated = await authRepository.isUserAuthenticated()
            
            if isFirebaseAuthenticated {
                // User is authenticated in Firebase, check for local user
                if let user = await userRepository.getCurrentUser() {
                    await MainActor.run { authState = .authenticated(user) }
                } else {
                    // Create guest user as fallback if no local user found
                    await createGuestUser()
                }
            } else {
                // Offline or token invalid; prefer last known local user without demoting
                if let user = await userRepository.getCurrentUser() {
                    await MainActor.run { authState = .authenticated(user) }
                } else {
                    await createGuestUser()
                }
            }
        } catch {
            // On error, create guest user
            await createGuestUser()
        }
    }
    
    private func createGuestUser() async {
        do {
            let userRepository = container.makeUserRepository(modelContext: modelContext)
            let guestUser = User.createGuest()
            try await userRepository.saveUser(guestUser)
            
            await MainActor.run {
                authState = .authenticated(guestUser)
            }
        } catch {
            await MainActor.run {
                authState = .unauthenticated
            }
        }
    }
    
    private func updateTheme(from user: User?) {
        // Theme is now handled at the app level via @AppStorage
        if let user = user {
            UserDefaults.standard.set(user.preferences.theme.rawValue, forKey: "selectedTheme")
        }
    }

    // MARK: - Connectivity
    private var connectivityOverlay: some View {
        return VStack(spacing: 0) {
            if !networkMonitor.isOnline {
                ConnectivityToast(text: "You are offline", background: .red)
            } else if showOnlineToast {
                ConnectivityToast(text: "Back online", background: .green)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let serverToastMessage {
                ConnectivityToast(text: serverToastMessage, background: .orange)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: networkMonitor.isOnline)
        .animation(.easeInOut(duration: 0.2), value: showOnlineToast)
        .animation(.easeInOut(duration: 0.2), value: serverToastMessage)
    }
    
    private func setupConnectivityObserver() {
        networkMonitor.$isOnline
            .receive(on: DispatchQueue.main)
            .sink { isOnline in
                if !isOnline {
                    wasOffline = true
                    showOnlineToast = false
                } else if wasOffline {
                    wasOffline = false
                    showOnlineToast = true
                    // Trigger incremental sync and statistics refresh when back online
                    Task { @MainActor in
                        let sync = container.makeSyncCoordinator(modelContext: modelContext)
                        if let last = container.getSyncControl().lastSuccessfulSyncAt {
                            try? await sync.incrementalSync(since: last)
                        } else {
                            try? await sync.initialFullSync()
                        }
                        container.getSyncControl().lastSuccessfulSyncAt = Date()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showOnlineToast = false
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Authentication State

enum AuthenticationState {
    case checking
    case authenticated(User)
    case unauthenticated
}

#Preview {
    let modelContainer = try! ModelContainer(for: PeeEvent.self)
    let container = DependencyContainer()
    
    ContentView()
        .environment(\.dependencyContainer, container)
        .modelContainer(modelContainer)
}
