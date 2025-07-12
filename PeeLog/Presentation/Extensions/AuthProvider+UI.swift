//
//  AuthProvider+UI.swift
//  PeeLog
//
//  Created by Arrinal S on 12/07/25.
//

import SwiftUI

// MARK: - AuthProvider UI Extensions
extension AuthProvider {
    var color: Color {
        switch self {
        case .apple:
            // Adaptive color that works in both light and dark modes
            return Color(.label)
        case .email:
            return .blue
        case .guest:
            return .orange
        }
    }
    
    var adaptiveColor: Color {
        switch self {
        case .apple:
            // Apple brand color that adapts to color scheme
            return Color(UIColor { traitCollection in
                switch traitCollection.userInterfaceStyle {
                case .dark:
                    return UIColor.white
                default:
                    return UIColor.black
                }
            })
        case .email:
            return .blue
        case .guest:
            return .orange
        }
    }
} 