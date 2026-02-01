//
//  PeeLogApp.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData
import FirebaseCore
import FirebaseFirestore
import FirebaseAnalytics
import AppIntents

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    // Configure Firestore settings (offline persistence, cache size)
    let settings = FirestoreSettings()
    settings.isPersistenceEnabled = true
    // Optional: unlimited cache to favor offline usage
    settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
    Firestore.firestore().settings = settings

    // Ensure Analytics collection is enabled regardless of plist flag
    Analytics.setAnalyticsCollectionEnabled(true)

    return true
  }
}

@main
struct PeeLogApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PeeEvent.self,
            User.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // State object for the container to ensure it stays alive during app lifetime
    @StateObject private var container = DependencyContainer()
    @AppStorage("selectedTheme") private var selectedTheme: String = "system"
    @State private var showLocationPermissionAlert = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencyContainer, container)
                .modelContainer(sharedModelContainer)
                .preferredColorScheme(colorScheme)
                .task { // handle first launch cold start
                    drainQuickLogQueue()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    drainQuickLogQueue()
                }
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .alert("Location Permission Required", isPresented: $showLocationPermissionAlert) {
                    Button("Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    Text("Location access is required to save this log. Enable location in Settings and try again.")
                }
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch selectedTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        case "system":
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Quick Log Queue Drain

extension PeeLogApp {
    @MainActor
    private func drainQuickLogQueue() {
        // Require an authenticated user before draining queued widget logs
        let anyUser = try? sharedModelContainer.mainContext.fetch(FetchDescriptor<User>()).first
        guard anyUser != nil else { return }
        let payloads = QuickLogQueue.drain()
        guard !payloads.isEmpty else { return }
        let repo = container.makePeeEventRepository(modelContext: sharedModelContainer.mainContext)
        var didAddAny = false
        for payload in payloads {
            let tsAny = payload["timestamp"]
            guard let tsVal = tsAny else { continue }
            let ts: Double = (tsVal as? Double) ?? (tsVal as? NSNumber)?.doubleValue ?? 0
            guard ts != 0 else { continue }
            guard let qualityRaw = payload["quality"] as? String,
                  let quality = PeeQuality(rawValue: qualityRaw) else { continue }
            let latAny = payload["latitude"]
            let lonAny = payload["longitude"]
            let lat: Double? = (latAny as? Double) ?? (latAny as? NSNumber)?.doubleValue
            let lon: Double? = (lonAny as? Double) ?? (lonAny as? NSNumber)?.doubleValue
            let name = payload["locationName"] as? String
            let event = PeeEvent(
                timestamp: Date(timeIntervalSince1970: ts),
                notes: nil,
                quality: quality,
                latitude: lat,
                longitude: lon,
                locationName: name,
                userId: nil
            )
            do {
                try repo.addEvent(event)
                didAddAny = true
                AnalyticsLogger.logQuickLog(mode: "no_loc", source: "widget_appintent", quality: quality)
            } catch {
                // keep failure silent in production
            }
        }
        if didAddAny {
            NotificationCenter.default.post(name: .eventsDidSync, object: nil)
        }
    }

    @MainActor
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "peelog" else { return }
        guard url.host == "quicklog" else { return }
        // Require an authenticated user before handling quicklog deeplink
        let anyUser = try? sharedModelContainer.mainContext.fetch(FetchDescriptor<User>()).first
        guard anyUser != nil else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = comps?.queryItems ?? []
        let qualityStr = items.first(where: { $0.name == "quality" })?.value
        guard let qualityStr, let quality = PeeQuality(rawValue: qualityStr) else {
            return
        }
        Task { @MainActor in
            let repo = container.makePeeEventRepository(modelContext: sharedModelContainer.mainContext)
            var lat: Double? = nil
            var lon: Double? = nil
            var name: String? = nil
            var hasValidLocation = false
            // Try to use current location if available
            let locRepo = container.getLocationRepository()
            do {
                let info = try await locRepo.getCurrentLocation()
                lat = info.data.coordinate.latitude
                lon = info.data.coordinate.longitude
                name = info.name
                hasValidLocation = true
            } catch let error as LocationError {
                switch error {
                case .permissionNotDetermined:
                    // Try to request permission and get location again
                    do {
                        try await locRepo.requestPermission()
                        let info = try await locRepo.getCurrentLocation()
                        lat = info.data.coordinate.latitude
                        lon = info.data.coordinate.longitude
                        name = info.name
                        hasValidLocation = true
                    } catch {
                        showLocationPermissionAlert = true
                        return
                    }
                case .permissionDenied, .permissionRestricted:
                    showLocationPermissionAlert = true
                    return
                default:
                    showLocationPermissionAlert = true
                    return
                }
            } catch {
                showLocationPermissionAlert = true
                return
            }
            guard hasValidLocation else {
                showLocationPermissionAlert = true
                return
            }
            let event = PeeEvent(
                timestamp: Date(),
                notes: nil,
                quality: quality,
                latitude: lat,
                longitude: lon,
                locationName: name,
                userId: nil
            )
            do {
                try repo.addEvent(event)
                NotificationCenter.default.post(name: .eventsDidSync, object: nil)
                AnalyticsLogger.logQuickLog(mode: "with_loc", source: "deeplink_widget", quality: quality)
            } catch {
                // keep failure silent in production
            }
        }
    }
}


