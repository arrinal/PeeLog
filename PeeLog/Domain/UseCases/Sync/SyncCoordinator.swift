//
//  SyncCoordinator.swift
//  PeeLog
//
//  Created by Arrinal S on 09/08/25.
//

import Foundation
@preconcurrency import FirebaseAuth

@MainActor
final class SyncCoordinator {
    enum SyncReason: String, Sendable {
        case appLaunch
        case authResolved
        case pullToRefresh
        case connectivityRestored
        case manual
    }
    
    private let peeEventRepository: PeeEventRepository
    private let userRepository: UserRepository
    private let firestoreService: FirestoreService
    private let syncControl: SyncControl
    
    private let defaultCooldownSeconds: TimeInterval = 20
    
    init(peeEventRepository: PeeEventRepository, userRepository: UserRepository, firestoreService: FirestoreService, syncControl: SyncControl) {
        self.peeEventRepository = peeEventRepository
        self.userRepository = userRepository
        self.firestoreService = firestoreService
        self.syncControl = syncControl
    }
    
    /// Single orchestrator entry-point: sync only when needed.
    /// - Full sync: only when there was never a successful sync.
    /// - Incremental sync: when we have a previous successful sync timestamp.
    /// - Cooldown: coalesce repeated triggers within a short window.
    func syncIfNeeded(reason: SyncReason, cooldownSeconds: TimeInterval? = nil) async throws {
        // If a sync is already running, coalesce/ignore.
        if syncControl.isBlocked { return }
        
        let cooldown = cooldownSeconds ?? defaultCooldownSeconds
        if let last = syncControl.lastSuccessfulSyncAt,
           Date().timeIntervalSince(last) < cooldown {
            #if DEBUG
            print("[Sync] Skip (cooldown) reason=\(reason.rawValue)")
            #endif
            return
        }
        
        if let last = syncControl.lastSuccessfulSyncAt {
            #if DEBUG
            print("[Sync] Incremental reason=\(reason.rawValue)")
            #endif
            try await incrementalSync(since: last)
        } else {
            #if DEBUG
            print("[Sync] Full reason=\(reason.rawValue)")
            #endif
            try await initialFullSync()
        }
    }
    
    /// Explicit recovery path for when a full sync is required.
    func forceFullSync(reason: SyncReason) async throws {
        if syncControl.isBlocked { return }
        #if DEBUG
        print("[Sync] Force full reason=\(reason.rawValue)")
        #endif
        try await initialFullSync()
    }
    
    // MARK: - Initial full sync
    func initialFullSync() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked { return }
        syncControl.isBlocked = true
        defer { syncControl.isBlocked = false }
        
        // If we already have local events (e.g., widget logs),
        // push them first so they won't be lost during replace.
        let localEvents = peeEventRepository.getAllEvents()
        if !localEvents.isEmpty {
            try await firestoreService.upsertEvents(uid: uid, events: localEvents)
        }

        // Pull cloud snapshot and merge into local (no destructive clear)
        let events = try await firestoreService.fetchAllEvents(uid: uid)
        try peeEventRepository.addEvents(events)
        NotificationCenter.default.post(name: .eventsDidSync, object: nil)
        syncControl.lastSuccessfulSyncAt = Date()
    }
    
    // MARK: - Incremental sync
    func incrementalSync(since: Date) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked { return }
        syncControl.isBlocked = true
        defer { syncControl.isBlocked = false }
        let user = await userRepository.getCurrentUser()
        guard user != nil else { return }
        
        // Upload local (all for now; could be optimized using metadata)
        let localEvents = peeEventRepository.getAllEvents()
        try await firestoreService.upsertEvents(uid: uid, events: localEvents)
        
        // Download remote changes since timestamp
        let remoteChanges = try await firestoreService.fetchEventsSince(uid: uid, since: since)
        if !remoteChanges.isEmpty {
            // Upsert by UUID; PeeEventRepositoryImpl.addEvents handles de-duplication
            try peeEventRepository.addEvents(remoteChanges)
            NotificationCenter.default.post(name: .eventsDidSync, object: nil)
        }
        syncControl.lastSuccessfulSyncAt = Date()
    }
    
    // MARK: - Logout sync
    func syncBeforeLogout() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked { return }
        // Upload any local events prior to logout
        let localEvents = peeEventRepository.getAllEvents()
        try await firestoreService.upsertEvents(uid: uid, events: localEvents)
        // Also ensure user profile stored
        if let user = await userRepository.getCurrentUser() {
            try await firestoreService.saveUser(uid: uid, localUser: user)
        }
    }

    // MARK: - Immediate single-event syncs
    func syncUpsertSingleEvent(_ event: PeeEvent) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked { return }
        let user = await userRepository.getCurrentUser()
        guard user != nil else { return }
        try await firestoreService.upsertEvents(uid: uid, events: [event])
        NotificationCenter.default.post(name: .eventsDidSync, object: nil)
    }

    func syncDeleteSingleEvent(_ event: PeeEvent) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked { return }
        let user = await userRepository.getCurrentUser()
        guard user != nil else { return }
        try await firestoreService.deleteEvent(uid: uid, eventId: event.id)
        NotificationCenter.default.post(name: .eventsDidSync, object: nil)
    }
}



