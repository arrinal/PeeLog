//
//  OnboardingProgressView.swift
//  PeeLog
//
//  Created by Arrinal S on 18/01/26.
//

import SwiftUI

struct OnboardingProgressView: View {
    let totalSteps: Int
    let currentStep: Int
    let onNext: () -> Void
    
    var body: some View {
        HStack {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index == currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: index == currentStep ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentStep)
                }
            }
            
            Spacer()
            
            // Next Button
            Button(action: onNext) {
                HStack(spacing: 4) {
                    Text(currentStep == totalSteps - 1 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                    
                    if currentStep != totalSteps - 1 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(24)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
}

#Preview {
    VStack {
        OnboardingProgressView(totalSteps: 3, currentStep: 0, onNext: {})
        OnboardingProgressView(totalSteps: 3, currentStep: 1, onNext: {})
        OnboardingProgressView(totalSteps: 3, currentStep: 2, onNext: {})
    }
}
