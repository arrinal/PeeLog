//
//  OnboardingSlide.swift
//  PeeLog
//
//  Created by Arrinal S on 18/01/26.
//

import Foundation

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let animationName: String
    let featureCards: [FeatureCard]?
    
    struct FeatureCard: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
    }
    
    static let slides: [OnboardingSlide] = [
        OnboardingSlide(
            title: "Quick log, no fuss",
            subtitle: "Track your health with just a tap. Simple, fast, and designed for you.",
            animationName: "onboarding_welcome",
            featureCards: nil
        ),
        OnboardingSlide(
            title: "Powerful Insights",
            subtitle: "Understand your habits with advanced PeeLog AI analytics and trends.",
            animationName: "onboarding_features",
            featureCards: [
                FeatureCard(icon: "icloud.fill", text: "Secure Cloud Sync"),
                FeatureCard(icon: "chart.bar.fill", text: "Deep Analytics"),
                FeatureCard(icon: "rectangle.3.group.bubble.fill", text: "Quick Widget")
            ]
        )
    ]
}
