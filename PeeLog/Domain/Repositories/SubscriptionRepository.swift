//
//  SubscriptionRepository.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
protocol SubscriptionRepository: AnyObject {
    func isEntitled(userId: UUID) async -> Bool
    func startTrialIfEligible(userId: UUID)
    func isTrialActive(userId: UUID) -> Bool
    func purchase() async -> Bool
    func restore() async -> Bool
    func daysRemainingInTrial(userId: UUID) -> Int
}



