//
//  ContentView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.dependencyContainer) private var container
    
    var body: some View {
        TabView {
            HomeView(viewModel: container.makeHomeViewModel())
                .tabItem {
                    Label("Home", systemImage: "drop.fill")
                }
            
            MapHistoryView(viewModel: container.makeMapHistoryViewModel())
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }
            
            StatisticsView(viewModel: container.makeStatisticsViewModel())
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
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