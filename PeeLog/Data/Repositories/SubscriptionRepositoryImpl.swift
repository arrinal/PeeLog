//
//  SubscriptionRepositoryImpl.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation

@MainActor
final class SubscriptionRepositoryImpl: SubscriptionRepository {
    private let service: SubscriptionService
    private let userDefaults: UserDefaults
    private let trialLengthDays: Int = 7

    init(service: SubscriptionService = SubscriptionService(), userDefaults: UserDefaults = .standard) {
        self.service = service
        self.userDefaults = userDefaults
    }

    func isEntitled(userId: UUID) async -> Bool {
        if await service.hasActiveEntitlement() { return true }
        return isTrialActive(userId: userId)
    }

    func startTrialIfEligible(userId: UUID) {
        let startKey = trialStartKey(userId)
        let consumedKey = trialConsumedKey(userId)
        if userDefaults.bool(forKey: consumedKey) { return }
        if userDefaults.object(forKey: startKey) == nil {
            userDefaults.set(Date(), forKey: startKey)
        }
    }

    func isTrialActive(userId: UUID) -> Bool {
        let startKey = trialStartKey(userId)
        let consumedKey = trialConsumedKey(userId)
        guard let start = userDefaults.object(forKey: startKey) as? Date else { return false }
        let end = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) ?? start
        let active = Date() < end
        if !active {
            userDefaults.set(true, forKey: consumedKey)
        }
        return active
    }

    func purchase() async -> Bool {
        await service.purchaseMonthly()
    }

    func restore() async -> Bool {
        await service.restorePurchases()
    }

    func daysRemainingInTrial(userId: UUID) -> Int {
        let startKey = trialStartKey(userId)
        guard let start = userDefaults.object(forKey: startKey) as? Date else { return 0 }
        let end = Calendar.current.date(byAdding: .day, value: trialLengthDays, to: start) ?? start
        let days = Calendar.current.dateComponents([.day], from: Date(), to: end).day ?? 0
        return max(0, days)
    }

    private func trialStartKey(_ userId: UUID) -> String { "trialStart_\(userId.uuidString)" }
    private func trialConsumedKey(_ userId: UUID) -> String { "trialConsumed_\(userId.uuidString)" }
}



