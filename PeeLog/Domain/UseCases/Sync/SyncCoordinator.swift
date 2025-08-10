//
//  SyncCoordinator.swift
//  PeeLog
//
//  Created by Assistant on 09/08/25.
//

import Foundation
@preconcurrency import FirebaseAuth

@MainActor
final class SyncCoordinator {
    private let peeEventRepository: PeeEventRepository
    private let userRepository: UserRepository
    private let firestoreService: FirestoreService
    private let syncControl: SyncControl
    
    init(peeEventRepository: PeeEventRepository, userRepository: UserRepository, firestoreService: FirestoreService, syncControl: SyncControl) {
        self.peeEventRepository = peeEventRepository
        self.userRepository = userRepository
        self.firestoreService = firestoreService
        self.syncControl = syncControl
    }
    
    // MARK: - Initial full sync
    func initialFullSync() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked {
            return
        }
        
        // Pull cloud snapshot and replace local
        let events = try await firestoreService.fetchAllEvents(uid: uid)
        try peeEventRepository.clearAllEvents()
        try peeEventRepository.addEvents(events)
        NotificationCenter.default.post(name: .eventsDidSync, object: nil)
    }
    
    // MARK: - Incremental sync
    func incrementalSync(since: Date) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        if syncControl.isBlocked { return }
        let user = await userRepository.getCurrentUser()
        guard let user = user, !user.isGuest else { return }
        
        // Upload local (all for now; could be optimized using metadata)
        let localEvents = peeEventRepository.getAllEvents()
        try await firestoreService.upsertEvents(uid: uid, events: localEvents)
        
        // Download remote changes since timestamp
        let remoteChanges = try await firestoreService.fetchEventsSince(uid: uid, since: since)
        if !remoteChanges.isEmpty {
            // Simplest merge: overwrite local by re-adding (idempotent via same UUIDs)
            try peeEventRepository.addEvents(remoteChanges)
            NotificationCenter.default.post(name: .eventsDidSync, object: nil)
        }
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
}



