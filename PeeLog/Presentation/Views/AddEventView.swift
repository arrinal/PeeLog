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
        let container = DependencyContainer()
        _viewModel = StateObject(wrappedValue: container.makeAddEventViewModel())
    }
    
    init(viewModel: AddEventViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    @State private var showingMapInForm = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Material background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.90, green: 0.95, blue: 0.99)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Log New Event")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("Track your hydration levels")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                        
                        // Date & Time Card
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "calendar.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text("Date & Time")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    DatePicker("", selection: $viewModel.date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                                        .accentColor(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Time")
                                        .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                                    DatePicker("", selection: $viewModel.time, in: viewModel.isFutureDate ? ...Date() : ...Date.distantFuture, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact)
                                        .accentColor(.blue)
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                        .padding(.horizontal, 20)
                        
                        // Quality Selection Card
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "drop.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text("Pee Quality")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(spacing: 16) {
                                Text("Select urine color/clarity:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Quality Buttons
                                ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(PeeQuality.allCases, id: \.self) { quality in
                                            MaterialQualityButton(
                                                quality: quality, 
                                                isSelected: quality == viewModel.selectedQuality
                                            ) {
                                    withAnimation(.spring(dampingFraction: 0.7)) {
                                        viewModel.selectedQuality = quality
                                    }
                                }
                            }
                        }
                                    .padding(.horizontal, 20)
                                }
                                .padding(.horizontal, -20)
                        
                                // Selected Quality Info
                                VStack(spacing: 12) {
                            HStack {
                                Text(viewModel.selectedQuality.emoji)
                                            .font(.system(size: 24))
                                Text(viewModel.selectedQuality.rawValue)
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Spacer()
                            }
                                    
                            Text(viewModel.selectedQuality.description)
                                        .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(viewModel.selectedQuality.color.opacity(0.15))
                                )
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                        .padding(.horizontal, 20)
                        
                        // Location Card
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "location.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text("Location")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                                
                                Toggle("", isOn: $viewModel.includeLocation)
                                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onChange(of: viewModel.includeLocation) { _, newValue in
                            if newValue {
                                viewModel.requestLocationPermission()
                                viewModel.startUpdatingLocation()
                            } else {
                                viewModel.stopUpdatingLocation()
                            }
                        }
                }
                            
                            if viewModel.includeLocation {
                                VStack(spacing: 16) {
                                    Group {
                                        if viewModel.isLoadingLocation {
                                            HStack(spacing: 12) {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                    .scaleEffect(0.8)
                                                Text("Getting location...")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.secondary)
                                                Spacer()
                                            }
                                            .padding(16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.blue.opacity(0.05))
                                            )
                                        } else if let error = viewModel.lastError {
                                            HStack(spacing: 12) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .foregroundColor(.red)
                                                Text("Error: \(error)")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.red)
                                                Spacer()
                                            }
                                            .padding(16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.red.opacity(0.05))
                                            )
                                        } else if let locationName = viewModel.locationName {
                                            HStack(spacing: 12) {
                                                Image(systemName: "mappin.circle.fill")
                                                    .foregroundColor(.red)
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Current Location")
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.secondary)
                                                    Text(locationName)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.primary)
                                                }
                                                Spacer()
                }
                                            .padding(16)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color.green.opacity(0.05))
                                            )
                                        }
                                    }
                                    
                                    if let location = viewModel.location {
                                        Button(action: {
                                            showingMapInForm = true
                                        }) {
                                            VStack(spacing: 12) {
                                                Map(initialPosition: .region(MKCoordinateRegion(
                                                    center: location.coordinate,
                                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                                ))) {
                                                    Marker("Current Location", coordinate: location.coordinate)
                                                        .tint(.blue)
                                                }
                                                .disabled(true)
                                                .frame(height: 140)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                
                                                HStack {
                                                    Image(systemName: "hand.tap.fill")
                                                        .font(.system(size: 12))
                                                    Text("Tap to view larger map")
                                                        .font(.system(size: 13, weight: .medium))
                                                }
                                                .foregroundColor(.blue)
                                                .padding(.bottom, 8)
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
                                                        .foregroundColor(.blue)
                                                        .fontWeight(.semibold)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                        .padding(.horizontal, 20)
                        
                        // Notes Card
                        VStack(spacing: 20) {
                            HStack {
                                Image(systemName: "note.text")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                Text("Additional Information")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes (optional)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                TextField("Add any notes about this event...", text: $viewModel.notes, axis: .vertical)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.system(size: 16))
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.05))
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .autocorrectionDisabled()
                                    .lineLimit(3...6)
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
                        )
                        .padding(.horizontal, 20)
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            Button(action: {
                                withAnimation(.spring(dampingFraction: 0.7)) {
                                    viewModel.saveEvent(context: modelContext)
                                    dismiss()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                    Text("Save Event")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.blue,
                                                    Color.blue.opacity(0.8)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                                )
                            }
                            .disabled(viewModel.isFutureCombinedDateTime())
                            .opacity(viewModel.isFutureCombinedDateTime() ? 0.6 : 1.0)
                            
                            Button(action: {
                                withAnimation(.spring(dampingFraction: 0.7)) {
                        dismiss()
                    }
                            }) {
                                Text("Cancel")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationBarHidden(true)
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

// MARK: - Material Quality Button
struct MaterialQualityButton: View {
    let quality: PeeQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(quality.color)
                        .frame(width: 60, height: 60)
                        .shadow(
                            color: quality.color.opacity(0.3), 
                            radius: 4, 
                            x: 0, 
                            y: 2
                        )
                    
                    // Selection ring - more spaced out
                    if isSelected {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2)
                            .frame(width: 76, height: 76) // More space from circle
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
                    }
                    
                    Text(quality.emoji)
                        .font(.system(size: 22))
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                }
                .padding(.top, isSelected ? 8 : 12) // More top padding when selected
                
                VStack(spacing: 4) {
                    Text(quality.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(height: 28)
                    
                    // Subtle selection indicator
                    if isSelected {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 4, height: 4)
                            Text("Selected")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .opacity(0.8)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 12)
                    }
                }
                .padding(.bottom, isSelected ? 8 : 12) // More bottom padding when selected
            }
            .frame(minWidth: 85, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        isSelected ? 
                        Color.blue.opacity(0.04) : 
                        Color.clear
                    )
                    .stroke(
                        isSelected ? Color.blue.opacity(0.2) : Color.clear, 
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.0 : 1.0) // No scale effect to avoid clutter
        .animation(.spring(dampingFraction: 0.8, blendDuration: 0.2), value: isSelected)
    }
}

#Preview {
    AddEventView()
}
