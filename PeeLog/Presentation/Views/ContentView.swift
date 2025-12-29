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
    @State private var showPaywall = false
    
    var body: some View {
        Group {
            switch authState {
            case .checking:
                loadingView
                    .transition(.opacity)
            case .authenticated(let user):
                ZStack(alignment: .top) {
                    mainTabView
                    connectivityOverlay
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 1.05)),
                    removal: .opacity.combined(with: .scale(scale: 0.95))
                ))
                .onAppear {
                    currentUser = user
                    Task { @MainActor in
                        let sync = container.makeSyncCoordinator(modelContext: modelContext)
                        try? await sync.initialFullSync()
                        // Check subscription entitlement/trial
                        let subVM = container.makeSubscriptionViewModel(modelContext: modelContext)
                        await subVM.beginTrialIfEligible()
                        await subVM.refreshEntitlement()
                        showPaywall = !subVM.isEntitled
                    }
                }
            case .unauthenticated:
                AuthenticationView.makeWithDependencies(
                    container: container,
                    modelContext: modelContext
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                    removal: .opacity
                ))
            }
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(viewModel: container.makeSubscriptionViewModel(modelContext: modelContext))
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        authState = .authenticated(user)
                    }
                    if lastSyncedUserId != user.id {
                        lastSyncedUserId = user.id
                        Task { @MainActor in
                            let sync = container.makeSyncCoordinator(modelContext: modelContext)
                            try? await sync.initialFullSync()
                        }
                    }
                case .unauthenticated:
                    withAnimation(.easeInOut(duration: 0.4)) {
                        authState = .unauthenticated
                    }
                case .error:
                    withAnimation(.easeInOut(duration: 0.4)) {
                        authState = .unauthenticated
                    }
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
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            authState = .authenticated(user)
                        }
                    }
                }
            } else {
                // Prefer last known local authenticated user if present (e.g., offline reuse)
                if let user = await userRepository.getCurrentUser() {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            authState = .authenticated(user)
                        }
                    }
                } else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            authState = .unauthenticated
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    authState = .unauthenticated
                }
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

enum AuthenticationState: Equatable {
    case checking
    case authenticated(User)
    case unauthenticated
    
    static func == (lhs: AuthenticationState, rhs: AuthenticationState) -> Bool {
        switch (lhs, rhs) {
        case (.checking, .checking): return true
        case (.unauthenticated, .unauthenticated): return true
        case (.authenticated(let u1), .authenticated(let u2)): return u1.id == u2.id
        default: return false
        }
    }
}

#Preview {
    let modelContainer = try! ModelContainer(for: PeeEvent.self)
    let container = DependencyContainer()
    
    ContentView()
        .environment(\.dependencyContainer, container)
        .modelContainer(modelContainer)
}
