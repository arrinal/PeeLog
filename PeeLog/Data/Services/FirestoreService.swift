//
//  FirestoreService.swift
//  PeeLog
//
//  Created by Assistant on 09/08/25.
//

import Foundation
import FirebaseFirestore

/// Service responsible for interacting with Firebase Firestore
/// - Note: This service intentionally avoids leaking Firebase types to callers.
@MainActor
final class FirestoreService {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    // MARK: - User

    struct FirestoreUserData {
        let id: String
        let email: String?
        let displayName: String?
        let authProvider: String
        let isGuest: Bool
        let createdAt: Date
        let updatedAt: Date
        let preferences: UserPreferences
    }

    func saveUser(uid: String, localUser: User) async throws {
        let userRef = db.collection("users").document(uid)

        let userDoc: [String: Any] = [
            "id": uid,
            "email": localUser.email as Any,
            "displayName": localUser.displayName as Any,
            "authProvider": localUser.authProvider.rawValue,
            "isGuest": localUser.isGuest,
            "createdAt": localUser.createdAt,
            "updatedAt": Date()
        ]

        try await setData(documentRef: userRef, data: userDoc, merge: true)

        // Preferences in subcollection
        let prefRef = userRef.collection("preferences").document("app")
        let prefs = localUser.preferences
        let prefDoc: [String: Any] = [
            "notificationsEnabled": prefs.notificationsEnabled,
            "units": prefs.units.rawValue,
            "theme": prefs.theme.rawValue,
            "syncEnabled": prefs.syncEnabled
        ]

        try await setData(documentRef: prefRef, data: prefDoc, merge: true)
    }

    func fetchUser(uid: String) async throws -> FirestoreUserData? {
        let userRef = db.collection("users").document(uid)
        guard let userSnap = try await getDocument(documentRef: userRef), userSnap.exists,
              let data = userSnap.data() else {
            return nil
        }

        let email = data["email"] as? String
        let displayName = data["displayName"] as? String
        let provider = data["authProvider"] as? String ?? "guest"
        let isGuest = data["isGuest"] as? Bool ?? true
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()

        // Preferences
        let prefRef = userRef.collection("preferences").document("app")
        let prefData = try await getDocument(documentRef: prefRef)?.data() ?? [:]
        let notificationsEnabled = prefData["notificationsEnabled"] as? Bool ?? true
        let unitsRaw = prefData["units"] as? String ?? MeasurementUnit.metric.rawValue
        let themeRaw = prefData["theme"] as? String ?? ThemePreference.system.rawValue
        let syncEnabled = prefData["syncEnabled"] as? Bool ?? true

        let prefs = UserPreferences(
            notificationsEnabled: notificationsEnabled,
            units: MeasurementUnit(rawValue: unitsRaw) ?? .metric,
            theme: ThemePreference(rawValue: themeRaw) ?? .system,
            syncEnabled: syncEnabled
        )

        return FirestoreUserData(
            id: uid,
            email: email,
            displayName: displayName,
            authProvider: provider,
            isGuest: isGuest,
            createdAt: createdAt,
            updatedAt: updatedAt,
            preferences: prefs
        )
    }

    // MARK: - Events

    func upsertEvents(uid: String, events: [PeeEvent]) async throws {
        let batch = db.batch()
        let userEvents = db.collection("users").document(uid).collection("events")

        for event in events {
            let docId = event.id.uuidString
            let ref = userEvents.document(docId)
            let payload = encode(event: event, uid: uid)
            batch.setData(payload, forDocument: ref, merge: true)
        }

        try await commit(batch: batch)
    }

    func fetchAllEvents(uid: String) async throws -> [PeeEvent] {
        let eventsRef = db.collection("users").document(uid).collection("events")
        let snapshot = try await getDocuments(query: eventsRef.order(by: "updatedAt", descending: true))
        return snapshot.documents.compactMap { decodeEvent(uid: uid, document: $0) }
    }

    func fetchEventsSince(uid: String, since: Date) async throws -> [PeeEvent] {
        let eventsRef = db.collection("users").document(uid).collection("events")
        let query = eventsRef.whereField("updatedAt", isGreaterThan: since)
        let snapshot = try await getDocuments(query: query)
        return snapshot.documents.compactMap { decodeEvent(uid: uid, document: $0) }
    }

    // MARK: - Mapping

    private func encode(event: PeeEvent, uid: String) -> [String: Any] {
        var qualityIndex = 1 // default paleYellow
        switch event.quality {
        case .clear: qualityIndex = 0
        case .paleYellow: qualityIndex = 1
        case .yellow: qualityIndex = 2
        case .darkYellow: qualityIndex = 3
        case .amber: qualityIndex = 4
        }

        var payload: [String: Any] = [
            "id": event.id.uuidString,
            "userId": uid,
            "timestamp": event.timestamp,
            "quality": qualityIndex,
            "createdAt": event.timestamp, // fallback when not set separately
            "updatedAt": Date()
        ]

        if let notes = event.notes, !notes.isEmpty { payload["notes"] = notes }
        if let lat = event.latitude { payload["latitude"] = lat }
        if let lon = event.longitude { payload["longitude"] = lon }
        if let name = event.locationName, !name.isEmpty { payload["locationName"] = name }

        return payload
    }

    private func decodeEvent(uid: String, document: QueryDocumentSnapshot) -> PeeEvent? {
        let data = document.data()
        guard let idString = data["id"] as? String,
              let uuid = UUID(uuidString: idString),
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? data["timestamp"] as? Date else {
            return nil
        }
        let qualityIndex = data["quality"] as? Int ?? 1
        let quality: PeeQuality
        switch qualityIndex {
        case 0: quality = .clear
        case 1: quality = .paleYellow
        case 2: quality = .yellow
        case 3: quality = .darkYellow
        case 4: quality = .amber
        default: quality = .paleYellow
        }

        let event = PeeEvent(
            timestamp: timestamp,
            notes: data["notes"] as? String,
            quality: quality,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            locationName: data["locationName"] as? String,
            userId: nil
        )
        // Overwrite generated UUID with cloud-provided value to keep parity
        event.id = uuid
        return event
    }

    // MARK: - Async Helpers

    private func setData(documentRef: DocumentReference, data: [String: Any], merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            documentRef.setData(data, merge: merge) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func getDocument(documentRef: DocumentReference) async throws -> DocumentSnapshot? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot?, Error>) in
            documentRef.getDocument { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot)
                }
            }
        }
    }

    private func getDocuments(query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let snapshot = snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown Firestore error"]))
                }
            }
        }
    }

    private func commit(batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}


