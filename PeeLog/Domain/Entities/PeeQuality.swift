//
//  PeeQuality.swift
//  PeeLog
//
//  Created by Arrinal S on 06/05/25.
//

import SwiftUI

// Enum for pee quality
enum PeeQuality: String, Codable, CaseIterable {
    case clear = "Clear"
    case paleYellow = "Pale Yellow"
    case yellow = "Yellow"
    case darkYellow = "Dark Yellow"
    case amber = "Amber"
    
    var description: String {
        switch self {
        case .clear: 
            return "Well hydrated"
        case .paleYellow: 
            return "Normal hydration"
        case .yellow: 
            return "Might need water soon"
        case .darkYellow: 
            return "Dehydration warning"
        case .amber: 
            return "Dehydrated - drink water!"
        }
    }
    
    var color: Color {
        switch self {
        case .clear: return Color(red: 0.9, green: 0.98, blue: 1.0) // Almost clear/white
        case .paleYellow: return Color(red: 0.98, green: 0.98, blue: 0.7) // Pale yellow
        case .yellow: return Color(red: 1.0, green: 0.9, blue: 0.4) // Medium yellow
        case .darkYellow: return Color(red: 0.9, green: 0.7, blue: 0.2) // Dark yellow
        case .amber: return Color(red: 0.85, green: 0.5, blue: 0.1) // Amber
        }
    }
    
    var emoji: String {
        switch self {
        case .clear: return "💧"
        case .paleYellow: return "🌟"
        case .yellow: return "⚠️"
        case .darkYellow: return "🚨"
        case .amber: return "��"
        }
    }
} 