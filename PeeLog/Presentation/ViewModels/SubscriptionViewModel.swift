//
//  SubscriptionViewModel.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import Foundation
import SwiftUI

@MainActor
final class SubscriptionViewModel: ObservableObject {
    private let checkStatus: CheckSubscriptionStatusUseCase
    private let startTrial: StartTrialUseCase
    private let purchaseUseCase: PurchaseSubscriptionUseCase
    private let restoreUseCase: RestorePurchasesUseCase
    private let userRepository: UserRepository
    private let subscriptionRepository: SubscriptionRepository

    @Published var isEntitled = false
    @Published var isProcessing = false
    @Published var errorMessage: String = ""

    init(
        checkStatus: CheckSubscriptionStatusUseCase,
        startTrial: StartTrialUseCase,
        purchaseUseCase: PurchaseSubscriptionUseCase,
        restoreUseCase: RestorePurchasesUseCase,
        userRepository: UserRepository,
        subscriptionRepository: SubscriptionRepository
    ) {
        self.checkStatus = checkStatus
        self.startTrial = startTrial
        self.purchaseUseCase = purchaseUseCase
        self.restoreUseCase = restoreUseCase
        self.userRepository = userRepository
        self.subscriptionRepository = subscriptionRepository
    }

    func refreshEntitlement() async {
        isEntitled = await checkStatus.execute()
    }

    func beginTrialIfEligible() async {
        await startTrial.execute()
        await refreshEntitlement()
    }

    func trialDaysRemaining() async -> Int {
        guard let user = await userRepository.getCurrentUser() else { return 0 }
        return subscriptionRepository.daysRemainingInTrial(userId: user.id)
    }

    func purchase() async {
        isProcessing = true
        defer { isProcessing = false }
        let ok = await purchaseUseCase.execute()
        if !ok { errorMessage = "Purchase failed. Please try again." }
        await refreshEntitlement()
    }

    func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        let ok = await restoreUseCase.execute()
        if !ok { errorMessage = "No purchases to restore." }
        await refreshEntitlement()
    }
}



