//
//  MapHistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData
import MapKit

struct MapHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: MapHistoryViewModel
    @State private var showingSheet = false
    @State private var showingPopup = false
    @State private var popupPosition: CGPoint = .zero
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            mapViewContent
        }
        .onAppear {
            viewModel.loadEventsWithLocation(context: modelContext)
            mapCameraPosition = viewModel.mapCameraPosition
        }
        .onChange(of: viewModel.mapCameraPosition) { oldValue, newValue in
            mapCameraPosition = newValue
        }
    }
    
    private var mapViewContent: some View {
        ZStack {
            mainMapView
            popupOverlay
            bottomInfoView
        }
        .navigationTitle("Pee Map")
        .sheet(isPresented: $showingSheet) {
            if let selectedEvent = viewModel.selectedEvent {
                LocationMapView(event: selectedEvent)
            }
        }
    }
    
    private var mainMapView: some View {
        Map(position: $mapCameraPosition, selection: $viewModel.selectedEvent) {
            mapAnnotations
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange { context in
            mapCameraPosition = .camera(context.camera)
        }
    }
    
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        ForEach(viewModel.eventsWithLocation, id: \.id) { event in
            if let coordinate = event.locationCoordinate {
                Annotation(
                    event.locationName ?? "Pee Event",
                    coordinate: coordinate
                ) {
                    pinView(for: event)
                }
            }
        }
    }
    
    private func pinView(for event: PeeEvent) -> some View {
        PeeMapPin(event: event, isSelected: viewModel.selectedEvent?.id == event.id)
            .onTapGesture {
                handlePinTap(event: event)
            }
    }
    
    @ViewBuilder
    private var popupOverlay: some View {
        if let selectedEvent = viewModel.selectedEvent, showingPopup {
            PeeEventPopup(event: selectedEvent) {
                closePopup()
            } onDetailTap: {
                showingSheet = true
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
        }
    }
    
    private var bottomInfoView: some View {
        VStack {
            Spacer()
            Text("\(viewModel.eventsWithLocation.count) events on map")
                .font(.caption)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.bottom, 8)
        }
    }
    
    private func handlePinTap(event: PeeEvent) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if viewModel.selectedEvent?.id == event.id {
                viewModel.selectedEvent = nil
                showingPopup = false
            } else {
                viewModel.selectedEvent = event
                showingPopup = true
            }
        }
    }
    
    private func closePopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingPopup = false
            viewModel.selectedEvent = nil
        }
    }
}

// MARK: - Custom Map Pin Component
struct PeeMapPin: View {
    let event: PeeEvent
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Outer ring for selection
            Circle()
                .fill(event.quality.color.opacity(0.3))
                .frame(width: isSelected ? 44 : 0, height: isSelected ? 44 : 0)
                .scaleEffect(isSelected ? 1.0 : 0.1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            
            // Main pin circle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            event.quality.color,
                            event.quality.color.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 2)
                )
                .shadow(
                    color: event.quality.color.opacity(0.4),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            
            // Quality emoji
            Text(event.quality.emoji)
                .font(.system(size: isSelected ? 14 : 10, weight: .medium))
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - Popup Component
struct PeeEventPopup: View {
    let event: PeeEvent
    let onClose: () -> Void
    let onDetailTap: () -> Void
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: event.timestamp)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: event.timestamp)
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Main popup content
                VStack(spacing: 16) {
                    // Header with quality indicator
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(event.quality.color)
                                .frame(width: 48, height: 48)
                                .shadow(color: event.quality.color.opacity(0.4), radius: 6, x: 0, y: 3)
                            
                            Text(event.quality.emoji)
                                .font(.system(size: 20))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.quality.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(event.quality.description)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Divider()
                        .background(Color.secondary.opacity(0.3))
                    
                    // Time and date info
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            Text(timeString)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            Text(dateString)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        
                        // Location info
                        if let locationName = event.locationName {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                Text(locationName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Spacer()
                            }
                        }
                        
                        // Notes if available
                        if let notes = event.notes, !notes.isEmpty {
                            HStack {
                                Image(systemName: "note.text")
                                    .font(.system(size: 14))
                                    .foregroundColor(.orange)
                                Text(notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                                Spacer()
                            }
                        }
                    }
                    
                    // Action button
                    Button(action: onDetailTap) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16))
                            Text("View Details")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue,
                                    Color.blue.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
                        )
                )
                .padding(.horizontal, 20)
                
                // Pointer arrow
                Triangle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 20, height: 12)
                    .overlay(
                        Triangle()
                            .fill(Color(.systemBackground))
                            .frame(width: 18, height: 10)
                    )
            }
            
            Spacer(minLength: 100)
        }
    }
}

// MARK: - Triangle Shape for Popup Pointer
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        
        return path
    }
}

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    let repository = PeeEventRepositoryImpl()
    let useCase = GetPeeEventsWithLocationUseCase(repository: repository)
    
    MapHistoryView(viewModel: MapHistoryViewModel(getPeeEventsWithLocationUseCase: useCase))
        .modelContainer(container)
} 