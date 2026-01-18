//
//  PeeLogDetailSheetView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import MapKit

struct PeeLogDetailSheetView: View {
    let event: PeeEvent?
    @Environment(\.dismiss) private var dismiss
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @State private var snapshot: EventSnapshot = EventSnapshot.empty
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let quality = snapshot.quality, let timestamp = snapshot.timestamp {
                    if let coordinate = snapshot.coordinate {
                        // Map view
                        Map(position: $mapCameraPosition) {
                            Marker(snapshot.locationName ?? "Pee Location", coordinate: coordinate)
                                .tint(.red)
                        }
                        .transaction { tx in
                            tx.disablesAnimations = true
                        }
                        .onAppear {
                            // Set initial camera position when the view appears
                            mapCameraPosition = .region(
                                MKCoordinateRegion(
                                    center: coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )
                            )
                        }
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                    
                    // Event details
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Circle()
                                .fill(quality.color)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                            
                            Text(quality.emoji)
                                .font(.headline)
                            
                            Text(quality.rawValue)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(timestamp, style: .time)
                                .font(.headline)
                        }
                        .padding(.bottom, 4)
                        
                        if let locationName = snapshot.locationName, !locationName.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Location")
                                        .font(.headline)
                                }
                                
                                Text(locationName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let notes = snapshot.notes, !notes.isEmpty {
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "note.text")
                                    Text("Notes")
                                        .font(.headline)
                                }
                                
                                Text(notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "drop.fill")
                                    .foregroundColor(.blue)
                                Text("Hydration Status")
                                    .font(.headline)
                            }
                            
                            Text(quality.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.05))
                } else {
                    // Fallback if no valid event is passed
                    VStack(spacing: 20) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No location data available")
                            .font(.headline)
                        
                        Text("The selected entry doesn't have location information.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(snapshot.locationName ?? "PeeLog Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let e = event {
                snapshot = EventSnapshot(
                    coordinate: e.locationCoordinate,
                    quality: e.quality,
                    timestamp: e.timestamp,
                    locationName: e.locationName,
                    notes: e.notes
                )
                if let coord = snapshot.coordinate {
                    mapCameraPosition = .region(
                        MKCoordinateRegion(
                            center: coord,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsStoreWillReset)) { _ in
            Task { @MainActor in
                // Dismiss to ensure no SwiftData references linger while store resets
                dismiss()
            }
        }
        .onDisappear {
            // Clear map state to avoid Metal drawable assertions
            mapCameraPosition = .automatic
        }
    }
}

private struct EventSnapshot {
    let coordinate: CLLocationCoordinate2D?
    let quality: PeeQuality?
    let timestamp: Date?
    let locationName: String?
    let notes: String?
    
    static let empty = EventSnapshot(
        coordinate: nil,
        quality: nil,
        timestamp: nil,
        locationName: nil,
        notes: nil
    )
}

#Preview {
    PeeLogDetailSheetView(event: PeeEvent(
        timestamp: Date(),
        notes: "Test note",
        quality: .paleYellow,
        latitude: 37.7749,
        longitude: -122.4194,
        locationName: "San Francisco"
    ))
} 
