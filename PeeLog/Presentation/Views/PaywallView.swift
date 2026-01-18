//
//  PaywallView.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel: SubscriptionViewModel
    private let onEntitlementChanged: ((EntitlementStatus) -> Void)?

    init(viewModel: SubscriptionViewModel, onEntitlementChanged: ((EntitlementStatus) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onEntitlementChanged = onEntitlementChanged
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                LottieView(animationName: "paywall_waterdrop", loopMode: .loop)
                    .frame(height: 250)
                    .padding(.horizontal)

                Text("Unlock PeeLog Premium")
                    .font(.largeTitle).bold()
                Text("Get full access with cloud sync and insights.")
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    Label("Cloud backup and sync", systemImage: "icloud.fill")
                    Label("Advanced PeeLog AI analytics", systemImage: "chart.bar.fill")
                    Label("Widget quick log", systemImage: "rectangle.3.group.bubble.fill")
                }
                .foregroundColor(.primary)

                VStack(spacing: 12) {
                    Button(action: { Task { await viewModel.startPurchaseFlow() } }) {
                        Text("Subscribe $5/month")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isProcessing)

                    Button(action: { Task { await viewModel.startRestoreFlow() } }) {
                        Text("Restore Purchases")
                            .font(.subheadline)
                    }
                }
                
                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("Subscription billed via Apple ID.")
                    Text("Sign in with Apple required to continue.")
                }
                .font(.footnote)
                .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.refreshEntitlement() }
            .onChange(of: viewModel.entitlementStatus) { _, newValue in
                onEntitlementChanged?(newValue)
            }
        }
    }
}

