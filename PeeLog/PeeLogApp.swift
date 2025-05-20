//
//  PeeLogApp.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData

@main
struct PeeLogApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            PeeEvent.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // State object for the container to ensure it stays alive during app lifetime
    @StateObject private var container: DependencyContainer

    // Initialize the container in init to avoid optional
    init() {
        let context = ModelContext(sharedModelContainer)
        _container = StateObject(wrappedValue: DependencyContainer(modelContext: context))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.dependencyContainer, container)
                .modelContainer(sharedModelContainer)
        }
    }
}


