//
//  LocationMapView.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI
import MapKit

struct LocationMapView: View {
    let event: PeeEvent?
    @Environment(\.dismiss) private var dismiss
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let event = event, let coordinate = event.locationCoordinate {
                    // Map view
                    Map(position: $mapCameraPosition) {
                        Marker(event.locationName ?? "Pee Location", coordinate: coordinate)
                            .tint(.blue)
                    }
                    .onAppear {
                        // Set initial camera position when the view appears
                        mapCameraPosition = .region(MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                    }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Event details
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Circle()
                                .fill(event.quality.color)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                            
                            Text(event.quality.emoji)
                                .font(.headline)
                            
                            Text(event.quality.rawValue)
                                .font(.headline)
                            
                            Spacer()
                            
                            Text(event.timestamp, style: .time)
                                .font(.headline)
                        }
                        .padding(.bottom, 4)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text("Location")
                                    .font(.headline)
                            }
                            
                            Text(event.locationName ?? "Unknown location")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let notes = event.notes, !notes.isEmpty {
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
                            
                            Text(event.quality.description)
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
            .navigationTitle(event?.locationName ?? "Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    LocationMapView(event: PeeEvent(
        timestamp: Date(),
        notes: "Test note",
        quality: .paleYellow,
        latitude: 37.7749,
        longitude: -122.4194,
        locationName: "San Francisco"
    ))
}
