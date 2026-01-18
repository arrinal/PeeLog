//
//  OnboardingView.swift
//  PeeLog
//
//  Created by Arrinal S on 18/01/26.
//

import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    @State private var currentPage = 0
    private let slides = OnboardingSlide.slides
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color
            Color(.systemBackground).ignoresSafeArea()
            
            // Pager
            TabView(selection: $currentPage) {
                ForEach(0..<slides.count, id: \.self) { index in
                    OnboardingSlideView(slide: slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)
            
            // Navigation & Progress
            OnboardingProgressView(
                totalSteps: slides.count,
                currentStep: currentPage,
                onNext: {
                    if currentPage < slides.count - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        onContinue()
                    }
                }
            )
            // Extra padding for bottom safe area is handled by OnboardingProgressView padding
            .padding(.bottom, 20)
        }
        .overlay(alignment: .topLeading) {
            // Back button
            if currentPage > 0 {
                Button(action: {
                    withAnimation {
                        currentPage -= 1
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding()
                }
                .transition(.opacity)
                .padding(.top, 40) // Approximate status bar padding
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Lottie Animation
            LottieView(animationName: slide.animationName, loopMode: .playOnce)
                .frame(height: 350)
                .padding(.horizontal)
            
            VStack(spacing: 16) {
                Text(slide.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Text(slide.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                if let features = slide.featureCards {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(features) { feature in
                            HStack(spacing: 12) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                
                                Text(feature.text)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                }
            }
            
            Spacer()
            Spacer() // Push content up a bit to leave room for controls
        }
        .padding()
    }
}

#Preview {
    OnboardingView(onContinue: {})
}
