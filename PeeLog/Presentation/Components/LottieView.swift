//
//  LottieView.swift
//  PeeLog
//
//  Created by Arrinal S on 18/01/26.
//

import SwiftUI
#if canImport(Lottie)
import Lottie
#endif

struct LottieView: UIViewRepresentable {
    let animationName: String
    let loopMode: LoopMode
    
    enum LoopMode {
        case playOnce
        case loop
        case autoReverse
        
        #if canImport(Lottie)
        var lottieMode: LottieLoopMode {
            switch self {
            case .playOnce: return .playOnce
            case .loop: return .loop
            case .autoReverse: return .autoReverse
            }
        }
        #endif
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.clipsToBounds = true
        container.backgroundColor = .clear

        #if canImport(Lottie)
        let animationView = LottieAnimationView(name: animationName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.loopMode = loopMode.lottieMode
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.play()
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        context.coordinator.animationView = animationView
        context.coordinator.currentAnimationName = animationName
        #else
        container.backgroundColor = .secondarySystemBackground
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Lottie: \(animationName)"
        label.textAlignment = .center
        label.textColor = .label
        label.numberOfLines = 0
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        #endif

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(Lottie)
        guard let animationView = context.coordinator.animationView else { return }
        if context.coordinator.currentAnimationName != animationName {
            animationView.animation = LottieAnimation.named(animationName)
            context.coordinator.currentAnimationName = animationName
        }
        animationView.loopMode = loopMode.lottieMode
        if !animationView.isAnimationPlaying {
            animationView.play()
        }
        #endif
    }

    final class Coordinator {
        #if canImport(Lottie)
        var animationView: LottieAnimationView?
        var currentAnimationName: String?
        #endif
    }
}
