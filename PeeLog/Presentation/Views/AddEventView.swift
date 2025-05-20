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
    
    @StateObject private var viewModel: AddEventViewModel
    
    init() {
        // Use StateObject with a default empty initialization
        _viewModel = StateObject(wrappedValue: AddEventViewModel(
            addPeeEventUseCase: AddPeeEventUseCase(
                repository: PeeEventRepositoryImpl(
                    modelContext: try! ModelContainer(for: PeeEvent.self).mainContext
                )
            ),
            locationService: LocationService()
        ))
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
                        viewModel.saveEvent()
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
    AddEventView(viewModel: AddEventViewModel(
        addPeeEventUseCase: AddPeeEventUseCase(
            repository: PeeEventRepositoryImpl(
                modelContext: try! ModelContainer(for: PeeEvent.self).mainContext
            )
        ),
        locationService: LocationService()
    ))
} 