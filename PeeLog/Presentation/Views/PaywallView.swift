//
//  PaywallView.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    @StateObject private var viewModel: SubscriptionViewModel
    private let onEntitlementChanged: ((EntitlementStatus) -> Void)?

    @State private var monthlyPriceText: String = "$5"
    private let monthlyProductId = "com.arrinal.PeeLog.subscription.monthly"

    init(viewModel: SubscriptionViewModel, onEntitlementChanged: ((EntitlementStatus) -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onEntitlementChanged = onEntitlementChanged
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                LottieView(animationName: "paywall_waterdrop", loopMode: .loop)
                    .frame(height: 250)
                    .padding(.horizontal)

                Text("Unlock PeeLog")
                    .font(.largeTitle).bold()
                Text("Get full access with cloud sync and insights.")
                    .foregroundColor(.secondary)
                Spacer()
                VStack(spacing: 12) {
                    Label("Cloud backup & sync across devices", systemImage: "icloud.fill")
                    Label("Smart insights & analytics (PeeLog AI)", systemImage: "chart.line.uptrend.xyaxis")
                    Label("Maps: see where you logs your pee", systemImage: "map.fill")
                    Label("Quick Log widget for one-tap logging", systemImage: "rectangle.3.group.bubble.fill")
                }
                .foregroundColor(.primary)
                Spacer()
                VStack(spacing: 12) {
                    Button(action: { Task { await viewModel.startPurchaseFlow() } }) {
                        Text("Subscribe \(monthlyPriceText)/month")
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

                    HStack(spacing: 12) {
                        Link("Privacy Policy", destination: URL(string: "https://peelog.app/privacy")!)
                        Text("•")
                        Link("Terms of Use", destination: URL(string: "https://peelog.app/terms")!)
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.refreshEntitlement()
                await loadPriceFromStoreKit()
            }
            .onChange(of: viewModel.entitlementStatus) { _, newValue in
                onEntitlementChanged?(newValue)
            }
        }
    }

    @MainActor
    private func loadPriceFromStoreKit() async {
        guard let product = try? await Product.products(for: [monthlyProductId]).first else { return }
        monthlyPriceText = product.displayPrice
    }
}
