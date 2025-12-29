//
//  PaywallView.swift
//  PeeLog
//
//  Created by Arrinal S on 05/11/25.
//

import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel: SubscriptionViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SubscriptionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.yellow)

                Text("Unlock PeeLog Premium")
                    .font(.largeTitle).bold()
                Text("Get full access with cloud sync and insights.")
                    .foregroundColor(.secondary)

                VStack(spacing: 12) {
                    Label("Cloud backup and sync", systemImage: "icloud.fill")
                    Label("Advanced analytics", systemImage: "chart.bar.fill")
                    Label("Widget quick log", systemImage: "rectangle.3.group.bubble.fill")
                }
                .foregroundColor(.primary)

                if #available(iOS 15.0, *) {
                    AsyncLabel(daysRemaining: viewModel)
                }

                VStack(spacing: 12) {
                    Button(action: { Task { await viewModel.purchase() } }) {
                        Text("Subscribe $5/month")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .foregroundColor(.white)
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .disabled(viewModel.isProcessing)

                    Button(action: { Task { await viewModel.restore() } }) {
                        Text("Restore Purchases")
                            .font(.subheadline)
                    }
                }

                Spacer()
                Text("7-day free trial for new users")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task { await viewModel.refreshEntitlement(); await viewModel.beginTrialIfEligible() }
        }
    }
}

@available(iOS 15.0, *)
private struct AsyncLabel: View {
    @ObservedObject var daysRemainingSource: SubscriptionViewModel
    @State private var days: Int = 0
    init(daysRemaining: SubscriptionViewModel) { self.daysRemainingSource = daysRemaining }
    var body: some View {
        Group {
            if days > 0 {
                Text("Trial: \(days) days left")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
        .task { days = await daysRemainingSource.trialDaysRemaining() }
    }
}



