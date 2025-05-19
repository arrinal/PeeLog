//
//  AddEventView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct AddEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var locationManager = LocationManager()
    
    @State private var date = Date()
    @State private var time = Date()
    @State private var notes = ""
    @State private var selectedQuality: PeeQuality = .paleYellow
    @State private var includeLocation = false
    @State private var showingMapInForm = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.334_900, longitude: -122.009_020),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    // Computed property to check if selected date is today
    private var isFutureDate: Bool {
        Calendar.current.isDateInToday(date) || Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    // Check if the combined date and time is in the future
    private func isFutureCombinedDateTime() -> Bool {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        var combinedComponents = DateComponents()
        combinedComponents.year = dateComponents.year
        combinedComponents.month = dateComponents.month
        combinedComponents.day = dateComponents.day
        combinedComponents.hour = timeComponents.hour
        combinedComponents.minute = timeComponents.minute
        
        let combinedDateTime = calendar.date(from: combinedComponents) ?? Date()
        
        return combinedDateTime > Date()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date and Time")) {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    DatePicker("Time", selection: $time, in: isFutureDate ? ...Date() : ...Date.distantFuture, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                }
                .listRowBackground(Color.blue.opacity(0.1))
                
                Section(header: Text("Pee Quality")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Select urine color/clarity:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 16) {
                            ForEach(PeeQuality.allCases, id: \.self) { quality in
                                QualityButton(quality: quality, isSelected: quality == selectedQuality) {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        selectedQuality = quality
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(selectedQuality.emoji)
                                Text(selectedQuality.rawValue)
                                    .font(.headline)
                            }
                            Text(selectedQuality.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listRowBackground(selectedQuality.color.opacity(0.2))
                
                Section(header: Text("Location")) {
                    Toggle("Include Current Location", isOn: $includeLocation)
                        .onChange(of: includeLocation) { _, newValue in
                            if newValue {
                                locationManager.requestPermission()
                                locationManager.startUpdatingLocation()
                            } else {
                                locationManager.stopUpdatingLocation()
                            }
                        }
                    
                    if includeLocation {
                        VStack(alignment: .leading, spacing: 10) {
                            Group {
                                if locationManager.isLoadingLocation {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                        Text("Getting location...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let error = locationManager.lastError {
                                    Text("Error: \(error)")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                } else if let locationName = locationManager.locationName {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.red)
                                        Text(locationName)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                            
                            if let location = locationManager.location {
                                Button(action: { 
                                    withAnimation {
                                        showingMapInForm.toggle()
                                    }
                                }) {
                                    Label(showingMapInForm ? "Hide Map" : "View on Map", systemImage: showingMapInForm ? "map.fill" : "map")
                                        .font(.subheadline)
                                }
                                .padding(.vertical, 5)
                                
                                if showingMapInForm {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(locationManager.locationName ?? "Current Location")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.bottom, 4)
                                        
                                        Map(initialPosition: .region(MKCoordinateRegion(
                                            center: location.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        ))) {
                                            Marker(locationManager.locationName ?? "Current Location", coordinate: location.coordinate)
                                                .tint(.red)
                                        }
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                        .padding(.bottom, 8)
                                    }
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.blue.opacity(0.1))

                
                Section(header: Text("Additional Information")) {
                    TextField("Notes (optional)", text: $notes)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Color.blue.opacity(0.1))
            }
            .navigationTitle("Log Pee Event")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .bold()
                    .disabled(isFutureCombinedDateTime())
                }
            }
            .background(Color.blue.opacity(0.1).ignoresSafeArea())
        }
    }
    
    private func saveEvent() {
        withAnimation {
            // Combine date and time components
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            
            var combinedComponents = DateComponents()
            combinedComponents.year = dateComponents.year
            combinedComponents.month = dateComponents.month
            combinedComponents.day = dateComponents.day
            combinedComponents.hour = timeComponents.hour
            combinedComponents.minute = timeComponents.minute
            
            var combinedTimestamp = calendar.date(from: combinedComponents) ?? Date()
            
            // Extra validation to ensure we're not in the future
            if combinedTimestamp > Date() {
                combinedTimestamp = Date()
            }
            
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Create event with location if available and requested
            let newEvent: PeeEvent
            if includeLocation, let location = locationManager.location {
                newEvent = PeeEvent(
                    timestamp: combinedTimestamp,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    quality: selectedQuality,
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    locationName: locationManager.locationName
                )
            } else {
                newEvent = PeeEvent(
                    timestamp: combinedTimestamp,
                    notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                    quality: selectedQuality
                )
            }
            modelContext.insert(newEvent)
            dismiss()
        }
    }
}

#Preview {
    AddEventView()
        .modelContainer(for: PeeEvent.self, inMemory: true)
}
