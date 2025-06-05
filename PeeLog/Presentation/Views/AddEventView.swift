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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencyContainer) private var container
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel: AddEventViewModel
    
    init() {
        // Use StateObject with dependency container for proper initialization
        let container = DependencyContainer()
        _viewModel = StateObject(wrappedValue: container.makeAddEventViewModel())
    }
    
    // Initialize with a provided viewModel (for dependency injection)
    init(viewModel: AddEventViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    @State private var showingMapInForm = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Date and Time")) {
                    DatePicker("Date", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    DatePicker("Time", selection: $viewModel.time, in: viewModel.isFutureDate ? ...Date() : ...Date.distantFuture, displayedComponents: .hourAndMinute)
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
                                QualityButton(quality: quality, isSelected: quality == viewModel.selectedQuality) {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        viewModel.selectedQuality = quality
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(viewModel.selectedQuality.emoji)
                                Text(viewModel.selectedQuality.rawValue)
                                    .font(.headline)
                            }
                            Text(viewModel.selectedQuality.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                    }
                }
                .listRowBackground(viewModel.selectedQuality.color.opacity(0.2))
                
                Section(header: Text("Location")) {
                    Toggle("Include Current Location", isOn: $viewModel.includeLocation)
                        .onChange(of: viewModel.includeLocation) { _, newValue in
                            if newValue {
                                viewModel.requestLocationPermission()
                                viewModel.startUpdatingLocation()
                            } else {
                                viewModel.stopUpdatingLocation()
                            }
                        }
                    
                    if viewModel.includeLocation {
                        VStack(alignment: .leading, spacing: 10) {
                            Group {
                                if viewModel.isLoadingLocation {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                        Text("Getting location...")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                } else if let error = viewModel.lastError {
                                    Text("Error: \(error)")
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                } else if let locationName = viewModel.locationName {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.red)
                                        Text(locationName)
                                            .font(.subheadline)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                            
                            if let location = viewModel.location {
                                Button(action: {
                                    showingMapInForm = true
                                }) {
                                    VStack(spacing: 8) {
                                        Map(initialPosition: .region(MKCoordinateRegion(
                                            center: location.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        ))) {
                                            Marker("Current Location", coordinate: location.coordinate)
                                                .tint(.blue)
                                        }
                                        .disabled(true)
                                        .frame(height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        
                                        Text("Tap to view larger map")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .sheet(isPresented: $showingMapInForm) {
                                    NavigationStack {
                                        Map(initialPosition: .region(MKCoordinateRegion(
                                            center: location.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                        ))) {
                                            Marker("Current Location", coordinate: location.coordinate)
                                                .tint(.blue)
                                        }
                                        .navigationTitle("Event Location")
                                        .navigationBarTitleDisplayMode(.inline)
                                        .toolbar {
                                            ToolbarItem(placement: .navigationBarTrailing) {
                                                Button("Done") {
                                                    showingMapInForm = false
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listRowBackground(Color.blue.opacity(0.1))

                
                Section(header: Text("Additional Information")) {
                    TextField("Notes (optional)", text: $viewModel.notes)
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
                        viewModel.saveEvent(context: modelContext)
                        dismiss()
                    }
                    .bold()
                    .disabled(viewModel.isFutureCombinedDateTime())
                }
            }
            .background(Color.blue.opacity(0.1).ignoresSafeArea())
        }
        .onAppear {
            if viewModel.includeLocation {
                viewModel.requestLocationPermission()
                viewModel.startUpdatingLocation()
            }
        }
        .onDisappear {
            if viewModel.includeLocation {
                viewModel.stopUpdatingLocation()
            }
        }
    }
}

#Preview {
    let container = DependencyContainer()
    let modelContainer = try! ModelContainer(for: PeeEvent.self)
    
    AddEventView(viewModel: container.makeAddEventViewModel())
        .modelContainer(modelContainer)
}
