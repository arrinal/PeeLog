//
//  AIInsightRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 30/12/25.
//

import Foundation
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseFunctions

final class AIInsightRepositoryImpl: AIInsightRepository, @unchecked Sendable {
    private let db: Firestore
    private let functions: Functions

    init(db: Firestore = Firestore.firestore(), functions: Functions = Functions.functions()) {
        self.db = db
        self.functions = functions
    }

    func fetchDailyInsight() async throws -> AIInsight? {
        let uid = try await requireUid()
        return try await fetchInsight(uid: uid, docId: "daily")
    }

    func fetchWeeklyInsight() async throws -> AIInsight? {
        let uid = try await requireUid()
        return try await fetchInsight(uid: uid, docId: "weekly")
    }

    func fetchCustomInsight() async throws -> AIInsight? {
        let uid = try await requireUid()
        return try await fetchInsight(uid: uid, docId: "custom")
    }

    func canAskAIToday() async -> Bool {
        guard let uid = await AuthHelper.currentUid(), !uid.isEmpty else { return false }

        let today = Self.utcDayKey(Date())
        let ref = db.collection("users").document(uid).collection("aiRateLimit").document(today)

        do {
            let snap = try await getDocument(documentRef: ref)
            return !(snap?.exists ?? false)
        } catch {
            // If Firestore is unavailable, play safe: disable Ask AI button
            return false
        }
    }

    func askAI(question: String) async throws -> AskAIResponse {
        _ = try await requireUid() // ensure consistent error messaging
        do {
            let result: HTTPSCallableResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HTTPSCallableResult, Error>) in
                Task { @MainActor in
                    let callable = functions.httpsCallable("askAI")
                    callable.call(["question": question]) { result, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let result { continuation.resume(returning: result) }
                        else { continuation.resume(throwing: AIInsightRepositoryError.invalidResponse) }
                    }
                }
            }

            guard let dict = result.data as? [String: Any],
                  let insight = dict["insight"] as? String,
                  !insight.isEmpty else {
                throw AIInsightRepositoryError.invalidResponse
            }

            return AskAIResponse(insight: insight)
        } catch {
            throw mapFunctionsError(error)
        }
    }
}

// MARK: - Private helpers
private extension AIInsightRepositoryImpl {
    func requireUid() async throws -> String {
        guard let uid = await AuthHelper.currentUid(), !uid.isEmpty else {
            throw AIInsightRepositoryError.notAuthenticated
        }
        return uid
    }

    func fetchInsight(uid: String, docId: String) async throws -> AIInsight? {
        let ref = db.collection("users").document(uid).collection("aiInsights").document(docId)
        let snap = try await getDocument(documentRef: ref)
        guard let snap, snap.exists, let data = snap.data() else { return nil }
        return parseInsight(from: data)
    }

    func parseInsight(from data: [String: Any]) -> AIInsight? {
        guard let typeRaw = data["type"] as? String,
              let type = AIInsightType(rawValue: typeRaw),
              let content = data["content"] as? String,
              let ts = data["generatedAt"] as? Timestamp else {
            return nil
        }

        return AIInsight(
            type: type,
            content: content,
            generatedAt: ts.dateValue(),
            question: data["question"] as? String
        )
    }

    func mapFunctionsError(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain == FunctionsErrorDomain, let code = FunctionsErrorCode(rawValue: ns.code) {
            switch code {
            case .unauthenticated:
                return AIInsightRepositoryError.notAuthenticated
            case .resourceExhausted:
                return AIInsightRepositoryError.rateLimitExceeded
            case .invalidArgument:
                return AIInsightRepositoryError.backend(message: "Invalid question. Please try a different prompt.")
            default:
                break
            }
        }
        return AIInsightRepositoryError.backend(message: error.localizedDescription)
    }

    func getDocument(documentRef: DocumentReference) async throws -> DocumentSnapshot? {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot?, Error>) in
            documentRef.getDocument { snapshot, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: snapshot) }
            }
        }
    }

    static func utcDayKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = comps.year, let m = comps.month, let d = comps.day else { return "unknown" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

// MARK: - Auth Helper
private enum AuthHelper {
    static func currentUid() async -> String? {
        #if canImport(FirebaseAuth)
        return Auth.auth().currentUser?.uid
        #else
        return nil
        #endif
    }
}


