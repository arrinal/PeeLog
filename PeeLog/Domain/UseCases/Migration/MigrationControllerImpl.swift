//
//  MigrationControllerImpl.swift
//  PeeLog
//
//  Created by Assistant on 09/08/25.
//

import Foundation
@preconcurrency import FirebaseAuth

@MainActor
final class MigrationControllerImpl: MigrationController {
    private let userRepository: UserRepository
    private let peeEventRepository: PeeEventRepository
    private let firestoreService: FirestoreService
    
    init(
        userRepository: UserRepository,
        peeEventRepository: PeeEventRepository,
        firestoreService: FirestoreService
    ) {
        self.userRepository = userRepository
        self.peeEventRepository = peeEventRepository
        self.firestoreService = firestoreService
    }
    
    // MARK: - Migrate
    func migrateGuestData(guestUser: User, to authenticatedUser: User) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 1) Reassign local events' user association (if present) and upload to cloud
        let localEvents = peeEventRepository.getAllEvents()
        try await firestoreService.upsertEvents(uid: uid, events: localEvents)
        
        // 2) Upload user profile/preferences
        try await firestoreService.saveUser(uid: uid, localUser: authenticatedUser)
        
        // 3) Fetch full cloud snapshot and store locally (replace local events for consistency)
        let cloudEvents = try await firestoreService.fetchAllEvents(uid: uid)
        // Notify views that event store is about to be reset
        NotificationCenter.default.post(name: .eventsStoreWillReset, object: nil)
        try peeEventRepository.clearAllEvents()
        try peeEventRepository.addEvents(cloudEvents)
        // Notify views that reset completed
        NotificationCenter.default.post(name: .eventsStoreDidReset, object: nil)
        NotificationCenter.default.post(name: .eventsDidSync, object: nil)
        
        // 4) Remove guest user locally
        try await userRepository.deleteUser(guestUser)
    }
    
    // MARK: - Skip
    func skipMigration(authenticatedUser: User) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // 1) Clear all local data
        NotificationCenter.default.post(name: .eventsStoreWillReset, object: nil)
        try peeEventRepository.clearAllEvents()
        
        // 2) Fetch cloud user (if exists) and save preferences locally
        if let remote = try await firestoreService.fetchUser(uid: uid) {
            authenticatedUser.updatePreferences(remote.preferences)
            try await userRepository.updateUser(authenticatedUser)
        } else {
            // Ensure server has baseline user doc
            try await firestoreService.saveUser(uid: uid, localUser: authenticatedUser)
        }
        
        // 3) Fetch cloud events and store locally
        let cloudEvents = try await firestoreService.fetchAllEvents(uid: uid)
        try peeEventRepository.addEvents(cloudEvents)
        NotificationCenter.default.post(name: .eventsStoreDidReset, object: nil)
        NotificationCenter.default.post(name: .eventsDidSync, object: nil)
    }
}



