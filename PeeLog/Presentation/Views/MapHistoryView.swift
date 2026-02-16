//
//  MapHistoryView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct MapHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencyContainer) private var container
    @StateObject private var viewModel: MapHistoryViewModel
    @State private var showingSheet = false
    @State private var showingPopup = false
    @State private var popupPosition: CGPoint = .zero
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var selectedAnnotation: MapEventSnapshot? = nil
    @State private var isStoreResetting = false
    @State private var snapshots: [MapEventSnapshot] = []
    @State private var resolvingLocationIds: Set<UUID> = []
    
    init(viewModel: MapHistoryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            mapViewContent
        }
        .onAppear {
            viewModel.loadEventsWithLocation()
            mapCameraPosition = viewModel.mapCameraPosition
            refreshSnapshots()
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsStoreWillReset)) { _ in
            Task { @MainActor in
                // Clear selections and data to avoid referencing detached objects
                isStoreResetting = true
                selectedAnnotation = nil
                showingPopup = false
                viewModel.clearSelectedEvent()
                viewModel.eventsWithLocation = []
                snapshots = []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsStoreDidReset)) { _ in
            Task { @MainActor in
                isStoreResetting = false
                viewModel.loadEventsWithLocation()
                refreshSnapshots()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidSync)) { _ in
            Task { @MainActor in
                viewModel.loadEventsWithLocation()
                refreshSnapshots()
            }
        }
        .onChange(of: viewModel.mapCameraPosition) { oldValue, newValue in
            mapCameraPosition = newValue
        }
        .onChange(of: viewModel.eventsWithLocation) { _, _ in
            refreshSnapshots()
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
            if let selected = selectedAnnotation {
                let matchedEvent = viewModel.eventsWithLocation.first(where: { $0.id == selected.id })
                PeeLogDetailSheetView(event: matchedEvent)
            }
        }
    }
    
    private var mainMapView: some View {
        Map(position: $mapCameraPosition) {
            mapAnnotations
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange { context in
            if !isStoreResetting {
                mapCameraPosition = .camera(context.camera)
            }
        }
        .transaction { transaction in
            // Workaround for Metal drawable lifetime assertion: avoid animated Map state changes
            transaction.disablesAnimations = true
        }
        .onTapGesture { location in
            // iOS 18 fix: Close popup when tapping map background
            if showingPopup {
                Task { @MainActor in
                    // Small delay to prevent conflicts with pin tap
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second delay
                    if showingPopup { // Check again after delay
                        closePopup()
                    }
                }
            }
        }
        .onDisappear {
            // Ensure overlays are torn down before Map deallocates
            showingPopup = false
            showingSheet = false
            viewModel.clearSelectedEvent()
            selectedAnnotation = nil
        }
    }
    
    @MapContentBuilder
    private var mapAnnotations: some MapContent {
        ForEach(snapshots, id: \.id) { item in
            Annotation(
                {
                    let name = item.locationName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if name?.isEmpty == false {
                        return name!
                    }
                    return String(format: "%.4f, %.4f", item.coordinate.latitude, item.coordinate.longitude)
                }(),
                coordinate: item.coordinate
            ) {
                pinView(for: item)
            }
        }
    }
    
    private func pinView(for item: MapEventSnapshot) -> some View {
        PeeMapPin(item: item, isSelected: selectedAnnotation?.id == item.id)
            .onTapGesture {
                handlePinTap(item: item)
            }
            .allowsHitTesting(true) // iOS 18 fix: Ensure pin can receive taps
    }
    
    @ViewBuilder
    private var popupOverlay: some View {
        if let selected = selectedAnnotation, showingPopup, !isStoreResetting {
            PeeEventPopup(item: selected) {
                closePopup()
            } onDetailTap: {
                showingSheet = true
            }
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 0.8).combined(with: .opacity)
            ))
            .allowsHitTesting(true) // iOS 18 fix: Ensure popup can receive taps
            .zIndex(1000) // iOS 18 fix: Ensure popup stays on top
        }
    }
    
    private var bottomInfoView: some View {
                VStack {
                    Spacer()
                    Text("\(snapshots.count) events on map")
                        .font(.caption)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }
            }
    
    private func handlePinTap(item: MapEventSnapshot) {
        // iOS 18 fix: Prevent rapid state changes and conflicts
        if showingPopup && selectedAnnotation?.id == item.id {
            // Already showing popup for this event, close it
            closePopup()
        } else {
            // iOS 18 fix: Use async task to prevent immediate dismissal
            Task { @MainActor in
                // Close any existing popup first
                if showingPopup {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showingPopup = false
                    }
                    try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 second delay
                }
                
                // Set new selection and show popup
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedAnnotation = item
                    showingPopup = true
                }
            }
        }
    }
    
    private func closePopup() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showingPopup = false
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            selectedAnnotation = nil
        }
    }
}

// MARK: - Custom Map Pin Component
struct PeeMapPin: View {
    fileprivate let item: MapEventSnapshot
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            // Outer ring for selection
            Circle()
                .fill(item.quality.color.opacity(0.3))
                .frame(width: isSelected ? 44 : 0, height: isSelected ? 44 : 0)
                .scaleEffect(isSelected ? 1.0 : 0.1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            
            // Main pin circle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            item.quality.color,
                            item.quality.color.opacity(0.8)
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
                    color: item.quality.color.opacity(0.4),
                    radius: isSelected ? 8 : 4,
                    x: 0,
                    y: isSelected ? 4 : 2
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            
            // Quality emoji
            Text(item.quality.emoji)
                .font(.system(size: isSelected ? 14 : 10, weight: .medium))
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
    }
}

// MARK: - Popup Component
struct PeeEventPopup: View {
    fileprivate let item: MapEventSnapshot
    let onClose: () -> Void
    let onDetailTap: () -> Void
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: item.timestamp)
    }
    
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: item.timestamp)
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
                                .fill(item.quality.color)
                                .frame(width: 48, height: 48)
                                .shadow(color: item.quality.color.opacity(0.4), radius: 6, x: 0, y: 3)
                            
                            Text(item.quality.emoji)
                                .font(.system(size: 20))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.quality.rawValue)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text(item.quality.description)
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
                        if let locationName = item.locationName {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.teal)
                                Text(locationName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Spacer()
                            }
                        }
                        
                        // Notes if available
                        if let notes = item.notes, !notes.isEmpty {
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
    let dependencyContainer = DependencyContainer()
    
    MapHistoryView(viewModel: dependencyContainer.makeMapHistoryViewModel(modelContext: container.mainContext))
        .modelContainer(container)
        .environment(\.dependencyContainer, dependencyContainer)
} 

// Snapshot used to render Map content safely, without holding live SwiftData objects
private struct MapEventSnapshot: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let quality: PeeQuality
    let timestamp: Date
    let locationName: String?
    let notes: String?
}

private extension MapHistoryView {
    func refreshSnapshots() {
        guard !isStoreResetting else {
            snapshots = []
            return
        }
        // Resolve missing location names in background
        for event in viewModel.eventsWithLocation {
            resolveLocationNameIfNeeded(for: event)
        }
        snapshots = viewModel.eventsWithLocation.compactMap { event in
            guard let coordinate = event.locationCoordinate else { return nil }
            return MapEventSnapshot(
                id: event.id,
                coordinate: coordinate,
                quality: event.quality,
                timestamp: event.timestamp,
                locationName: event.locationName,
                notes: event.notes
            )
        }
    }

    @MainActor
    func resolveLocationNameIfNeeded(for event: PeeEvent) {
        guard event.hasLocation,
              let lat = event.latitude,
              let lon = event.longitude else { return }
        let trimmed = event.locationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard trimmed.isEmpty else { return }
        guard !resolvingLocationIds.contains(event.id) else { return }
        resolvingLocationIds.insert(event.id)
        let geocoder = CLGeocoder()
        Task { @MainActor in
            defer { resolvingLocationIds.remove(event.id) }
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(
                    CLLocation(latitude: lat, longitude: lon)
                )
                guard let placemark = placemarks.first else { return }
                let name = buildLocationName(from: placemark)
                guard let name, !name.isEmpty else { return }
                event.locationName = name
                try? modelContext.save()
                NotificationCenter.default.post(name: .eventsDidSync, object: nil)
                let sync = container.makeSyncCoordinator(modelContext: modelContext)
                Task { try? await sync.syncUpsertSingleEvent(event) }
            } catch {
                // keep failure silent
            }
        }
    }

    func buildLocationName(from placemark: CLPlacemark) -> String? {
        var name = ""
        if let thoroughfare = placemark.thoroughfare {
            name += thoroughfare
        }
        if let subThoroughfare = placemark.subThoroughfare {
            if !name.isEmpty { name += " " }
            name += subThoroughfare
        }
        if name.isEmpty, let locality = placemark.locality {
            name = locality
        }
        if name.isEmpty, let areaOfInterest = placemark.areasOfInterest?.first {
            name = areaOfInterest
        }
        return name.isEmpty ? nil : name
    }
}
