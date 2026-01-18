//
//  HomeView.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI
import SwiftData
import MapKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dependencyContainer) private var container
    @StateObject private var viewModel: HomeViewModel
    @State private var showingAddEventSheet = false
    @State private var selectedEvent: PeeEvent?
    @State private var showingMapSheet = false
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var isStoreResetting = false
    
    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background
                backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Card
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("PeeLog")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    Text("\(viewModel.todaysEvents.count) events tracked")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                // Hydration Status Circle
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color.blue.opacity(0.8),
                                                    Color.cyan.opacity(0.6)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 70, height: 70)
                                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                    
                                    VStack(spacing: 2) {
                                        Text("\(viewModel.todaysEvents.count)")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(.white)
                                        Text("events")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                            }
                        }
                        .padding(24)
                        .background(cardBackground)
                        .padding(.horizontal, 20)
                        
                        // Events List
                        VStack(spacing: 16) {
                                    HStack {
                                Text("Recent Events")
                                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                Spacer()
                                NavigationLink(destination: HistoryView()) {
                                    HStack(spacing: 4) {
                                        Text("View All")
                                            .font(.system(size: 14, weight: .medium))
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    }
                            }
                            .padding(.horizontal, 20)
                            
                            if viewModel.todaysEvents.isEmpty {
                                // Empty State Card
                                VStack(spacing: 16) {
                                    Image(systemName: "drop.circle")
                                        .font(.system(size: 48, weight: .light))
                                        .foregroundColor(.blue.opacity(0.6))
                                    
                                    VStack(spacing: 8) {
                                        Text("No events today")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.primary)
                                        Text("Start tracking your hydration")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(32)
                                .background(cardBackground)
                                .padding(.horizontal, 20)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(viewModel.todaysEvents, id: \.id) { event in
                                        EventCard(
                                            event: event,
                                            onTap: {
                                                selectedEvent = event
                                                showingMapSheet = true
                                            },
                                            onDelete: {
                                                withAnimation(.spring(dampingFraction: 0.8)) {
                                                    viewModel.deleteEvent(event: event)
                                                }
                                            }
                                        )
                                        .contextMenu {
                                            Button {
                                                withAnimation(.spring(dampingFraction: 0.8)) {
                                                    viewModel.deleteEvent(event: event)
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash.fill")
                                            }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                        .animation(.easeIn(duration: 0.2), value: viewModel.todaysEvents)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                                }
                    }
                    .padding(.bottom, 100) // Space for FAB
                }
                .refreshable {
                    let userRepository = container.makeUserRepository(modelContext: modelContext)
                    let user = await userRepository.getCurrentUser()
                    if user != nil, NetworkMonitor.shared.isOnline {
                        NotificationCenter.default.post(name: .requestInitialFullSync, object: nil)
                    }
                    await MainActor.run {
                        viewModel.loadTodaysEvents()
                    }
                }
                .transaction { tx in
                    if isStoreResetting { tx.disablesAnimations = true }
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { 
                            withAnimation(.spring(dampingFraction: 0.7)) {
                                showingAddEventSheet = true 
                            }
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(
                                    Circle()
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
                                        .shadow(color: Color.blue.opacity(0.4), radius: 12, x: 0, y: 6)
                                )
                        }
                        .scaleEffect(showingAddEventSheet ? 0.9 : 1.0)
                        .animation(.spring(dampingFraction: 0.6), value: showingAddEventSheet)
                        .padding(.trailing, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddEventSheet) {
                withAnimation(.easeIn(duration: 0.25)) {
                    viewModel.loadTodaysEvents()
                }
            } content: {
                AddEventView()
            }
            .sheet(isPresented: $showingMapSheet, onDismiss: {
                selectedEvent = nil
            }) {
                if let selectedEvent = selectedEvent {
                    PeeLogDetailSheetView(event: selectedEvent)
                        .ignoresSafeArea(.container, edges: .top)
                }
            }
            .onChange(of: selectedEvent) { oldValue, newValue in
                if isStoreResetting {
                    showingMapSheet = false
                    selectedEvent = nil
            } else if newValue != nil {
                showingMapSheet = true
                }
            }
        }
        .onAppear {
            viewModel.loadTodaysEvents()
            viewModel.refreshOnConnectivityChange(isOnline: NetworkMonitor.shared.isOnline)
        }
        .onReceive(NotificationCenter.default.publisher(for: .eventsDidSync)) { _ in
            // Ensure we hop to the main actor for UI-bound view model
            Task { @MainActor in
                withAnimation(.easeIn(duration: 0.25)) {
                    viewModel.loadTodaysEvents()
                }
            }
        }
                .onReceive(NotificationCenter.default.publisher(for: .eventsStoreWillReset)) { _ in
                    Task { @MainActor in
                        // Drop any references and reload from fresh store
                        withAnimation(.easeIn(duration: 0.2)) {
                            isStoreResetting = true
                            viewModel.todaysEvents = []
                            // Ensure any map sheets are dismissed while store resets
                            showingMapSheet = false
                            selectedEvent = nil
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .eventsStoreDidReset)) { _ in
                    Task { @MainActor in
                        withAnimation(.easeIn(duration: 0.25)) {
                            viewModel.loadTodaysEvents()
                            isStoreResetting = false
                        }
                    }
                }
        .onReceive(NetworkMonitor.shared.$isOnline) { isOnline in
            // Immediately reload local list regardless of status to avoid empty flicker
            viewModel.refreshOnConnectivityChange(isOnline: isOnline)
        }
    }
    
    // MARK: - Adaptive Colors
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                colorScheme == .dark ? 
                    Color(red: 0.05, green: 0.05, blue: 0.08) : 
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                colorScheme == .dark ? 
                    Color(red: 0.08, green: 0.08, blue: 0.12) : 
                    Color(red: 0.90, green: 0.95, blue: 0.99)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(
                color: colorScheme == .dark ? 
                    Color.white.opacity(0.05) : 
                    Color.black.opacity(0.08), 
                radius: 12, 
                x: 0, 
                y: 4
            )
    }
}

// MARK: - Event Card Component
struct EventCard: View {
    let event: PeeEvent
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    @State private var isDragging = false
    @State private var dragDirection: DragDirection = .none
    @State private var swipeActivated = false
    
    private let screenWidth = UIScreen.main.bounds.width
    private let deleteThreshold: CGFloat = UIScreen.main.bounds.width * 0.50
    private let leftSwipeActivation: CGFloat = 16 // slightly larger deadzone to avoid jitter
    private let directionThreshold: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Delete Background - expands to full screen width when swiping
            if offset < 0 {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.red)
                        .overlay(
                            HStack {
                                Spacer()
                                VStack(spacing: 4) {
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("Delete")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .opacity(min(abs(offset) / (deleteThreshold * 0.3), 1.0))
                                .scaleEffect(min(abs(offset) / (deleteThreshold * 0.3) * 0.5 + 0.5, 1.0))
                                .padding(.trailing, 20)
                            }
                        )
                        .frame(width: max(abs(offset), 0.1))
                        .cornerRadius(16, corners: [.topRight, .bottomRight])
                }
            }
            
            // Main Card Content
            HStack(spacing: 16) {
                // Quality Indicator
                ZStack {
                    Circle()
                        .fill(event.quality.color)
                        .frame(width: 52, height: 52)
                        .shadow(color: event.quality.color.opacity(0.4), radius: 6, x: 0, y: 3)
                    
                    Text(event.quality.emoji)
                        .font(.system(size: 20))
                }
                
                // Event Details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(event.timestamp, style: .time)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(event.quality.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.blue,
                                                event.quality.color
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                    }
                    ///
                    HStack(alignment: .top) {
                        VStack(alignment: .leading) {
                            if event.hasLocation, let locationName = event.locationName {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.teal)
                                    Text(locationName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(Color.blue.opacity(0.1))
                                )
                            }
                            
                            if let notes = event.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(event.quality.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                }
//                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: colorScheme == .dark ? 
                            Color.white.opacity(0.05) : 
                            Color.black.opacity(0.06), 
                        radius: 8, 
                        x: 0, 
                        y: 2
                    )
            )
            .offset(x: offset)
            .scaleEffect(isDeleting ? 0.9 : 1.0)
            .opacity(isDeleting ? 0.4 : 1.0)
            .animation(.none, value: offset)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture()
                    .onEnded {
                        guard !isDeleting, !isDragging, offset == 0 else { return }
                        onTap()
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        // Prevent interaction if already deleting
                        guard !isDeleting else { return }
                        
                        // Decide drag intent once with threshold so vertical scroll can begin immediately
                        if dragDirection == .none {
                            let absX = abs(value.translation.width)
                            let absY = abs(value.translation.height)
                            if absX > directionThreshold && absX > absY {
                                dragDirection = .horizontal
                            } else if absY > directionThreshold && absY > absX {
                                dragDirection = .vertical
                            } else {
                                return
                            }
                        }
                        
                        // Let vertical movement pass through to ScrollView (for pull-to-refresh and scroll)
                        guard dragDirection == .horizontal else { return }

                        // Horizontal drag handling with activation latch
                        isDragging = true
                        let tx = value.translation.width
                        
                        if !swipeActivated {
                            if tx <= -leftSwipeActivation {
                                swipeActivated = true
                            } else {
                                // Still in deadzone: keep card steady
                                offset = 0
                                return
                            }
                        }
                        
                        // Only allow left swipe (negative translation)
                        if tx < 0 {
                            // Compute distance past activation to keep smooth onset from 0
                            let effectiveTx = tx + leftSwipeActivation
                            let dragDistance = abs(effectiveTx)
                            
                            if dragDistance <= deleteThreshold {
                                // Linear movement until threshold
                                offset = -dragDistance
                            } else {
                                // Progressive resistance after threshold
                                let excess = dragDistance - deleteThreshold
                                let resistance = min(excess / (screenWidth * 0.25), 1.0)
                                let resisted = excess * (1.0 - resistance * 0.7)
                                offset = -(deleteThreshold + resisted)
                            }
                        } else {
                            // Dragging right while engaged: approach zero but don't overshoot
                            offset = 0
                        }
                    }
                    .onEnded { value in
                        // Prevent multiple gesture handling during deletion
                        guard !isDeleting else { return }
                        
                        // Mark as no longer dragging
                        isDragging = false
                        
                        defer { dragDirection = .none }
                        guard dragDirection == .horizontal else {
                            // Vertical drag finished: ensure reset
                            offset = 0
                            return
                        }
                        
                        let totalLeftTravel = max(0, -value.translation.width - leftSwipeActivation)
                        
                        // Decide deletion only if sufficiently far to the left
                        let shouldDelete = totalLeftTravel >= deleteThreshold
                        
                        if shouldDelete {
                            // Mark as deleting to prevent further interactions
                            isDeleting = true
                            
                            // Animate deletion - slide completely off screen
                            withAnimation(.easeOut(duration: 0.3)) {
                                offset = -screenWidth
                            }
                            
                            // Execute deletion after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDelete()
                            }
                        } else {
                            // Reset with a gentle spring
                            withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.86, blendDuration: 0.12)) {
                                offset = 0
                            }
                        }
                        swipeActivated = false
                    }
            )
        }
        .clipped()
    }
}

private enum DragDirection { case none, horizontal, vertical }

#Preview {
    let container = try! ModelContainer(for: PeeEvent.self)
    let dependencyContainer = DependencyContainer()
    
    HomeView(viewModel: dependencyContainer.makeHomeViewModel(modelContext: container.mainContext))
        .modelContainer(container)
        .environment(\.dependencyContainer, dependencyContainer)
} 


extension View {
    func stroke(color: Color, width: CGFloat = 1) -> some View {
        modifier(StrokeModifier(strokeSize: width, strokeColor: color))
    }
}

struct StrokeModifier: ViewModifier {
    private let id = UUID()
    var strokeSize: CGFloat = 1
    var strokeColor: Color = .blue
    
    func body(content: Content) -> some View {
        if strokeSize > 0 {
            appliedStrokeBackground(content: content)
        } else {
            content
        }
    }
    
    private func appliedStrokeBackground(content: Content) -> some View {
        content
            .padding(strokeSize*2)
            .background(
                Rectangle()
                    .foregroundColor(strokeColor)
                    .mask(alignment: .center) {
                        mask(content: content)
                    }
            )
    }
    
    func mask(content: Content) -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.01))
            if let resolvedView = context.resolveSymbol(id: id) {
                context.draw(resolvedView, at: .init(x: size.width/2, y: size.height/2))
            }
        } symbols: {
            content
                .tag(id)
                .blur(radius: strokeSize)
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
} 
