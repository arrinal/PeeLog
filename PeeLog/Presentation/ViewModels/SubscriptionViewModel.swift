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
    private let purchaseUseCase: PurchaseSubscriptionUseCase
    private let restoreUseCase: RestorePurchasesUseCase
    private let authenticateUserUseCase: AuthenticateUserUseCaseProtocol
    private let authRepository: AuthRepository
    private let userRepository: UserRepository

    @Published var isEntitled = false
    @Published var entitlementStatus: EntitlementStatus = .notEntitled
    @Published var isProcessing = false
    @Published var errorMessage: String = ""

    init(
        checkStatus: CheckSubscriptionStatusUseCase,
        purchaseUseCase: PurchaseSubscriptionUseCase,
        restoreUseCase: RestorePurchasesUseCase,
        authenticateUserUseCase: AuthenticateUserUseCaseProtocol,
        authRepository: AuthRepository,
        userRepository: UserRepository
    ) {
        self.checkStatus = checkStatus
        self.purchaseUseCase = purchaseUseCase
        self.restoreUseCase = restoreUseCase
        self.authenticateUserUseCase = authenticateUserUseCase
        self.authRepository = authRepository
        self.userRepository = userRepository
    }

    func refreshEntitlement() async {
        let status = await checkStatus.execute()
        entitlementStatus = status
        isEntitled = (status == .entitled)
    }

    func startPurchaseFlow() async {
        errorMessage = ""
        if await ensureAuthenticated() {
            await purchase()
        }
    }

    func startRestoreFlow() async {
        errorMessage = ""
        if await ensureAuthenticated() {
            await restore()
        }
    }

    func purchase() async {
        isProcessing = true
        defer { isProcessing = false }
        let localUser = await userRepository.getCurrentUser()
        let resolvedUser: User?
        if let localUser {
            resolvedUser = localUser
        } else {
            resolvedUser = await authRepository.getCurrentUser()
        }
        guard let user = resolvedUser else {
            errorMessage = "Please sign in to continue."
            return
        }
        let result = await purchaseUseCase.execute(userId: user.id)
        switch result {
        case .success:
            errorMessage = ""
        case .failed:
            errorMessage = "Purchase failed. Please try again."
        }
        await refreshEntitlement()
    }

    func restore() async {
        isProcessing = true
        defer { isProcessing = false }
        let localUser = await userRepository.getCurrentUser()
        let resolvedUser: User?
        if let localUser {
            resolvedUser = localUser
        } else {
            resolvedUser = await authRepository.getCurrentUser()
        }
        guard let user = resolvedUser else {
            errorMessage = "Please sign in to continue."
            return
        }
        let result = await restoreUseCase.execute(userId: user.id)
        switch result {
        case .success:
            errorMessage = ""
        case .failed:
            errorMessage = "No purchases to restore."
        }
        await refreshEntitlement()
    }
}

// MARK: - Auth Helper
private extension SubscriptionViewModel {
    func ensureAuthenticated() async -> Bool {
        if !NetworkMonitor.shared.isOnline {
            errorMessage = "Please connect to the internet to continue."
            return false
        }
        if await authRepository.isUserAuthenticated() {
            return true
        }
        do {
            _ = try await authenticateUserUseCase.signInWithApple()
            return true
        } catch let authError as AuthError {
            errorMessage = authError.errorDescription ?? "Sign in failed. Please try again."
            return false
        } catch {
            errorMessage = "Sign in failed. Please try again."
            return false
        }
    }
}



