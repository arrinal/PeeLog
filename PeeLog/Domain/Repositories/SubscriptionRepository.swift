//
//  SubscriptionRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

enum EntitlementStatus: Equatable {
    case entitled
    case notEntitled
}

enum PurchaseResult: Equatable {
    case success
    case failed
}

@MainActor
protocol SubscriptionRepository: AnyObject {
    func currentEntitlementStatus(userId: UUID) async -> EntitlementStatus
    func purchaseAndClaim(userId: UUID) async -> PurchaseResult
    func restoreAndClaim(userId: UUID) async -> PurchaseResult
}



