//
//  QualityButton.swift
//  PeeLog
//
//  Created by Arrinal S on 04/05/25.
//

import SwiftUI

struct QualityButton: View {
    let quality: PeeQuality
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                Circle()
                    .fill(quality.color)
                        .frame(width: 50, height: 50)
                        .shadow(
                            color: isSelected ? quality.color.opacity(0.6) : quality.color.opacity(0.3), 
                            radius: isSelected ? 10 : 5, 
                            x: 0, 
                            y: isSelected ? 5 : 3
                        )
                    .overlay(
                        Circle()
                                .stroke(
                                    isSelected ? Color.blue : Color.clear, 
                                    lineWidth: isSelected ? 3 : 0
                                )
                    )
                
                    Text(quality.emoji)
                        .font(.system(size: 20))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                
                VStack(spacing: 4) {
                    Text(quality.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    if isSelected {
                        Text("Selected")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.blue)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(minWidth: 70)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? quality.color.opacity(0.15) : Color.clear)
                    .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview
struct QualityButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
            QualityButton(quality: .clear, isSelected: true, action: {})
            QualityButton(quality: .paleYellow, isSelected: false, action: {})
            QualityButton(quality: .yellow, isSelected: false, action: {})
            QualityButton(quality: .darkYellow, isSelected: false, action: {})
            QualityButton(quality: .amber, isSelected: false, action: {})
            }
            
            HStack(spacing: 16) {
                QualityButton(quality: .clear, isSelected: false, action: {})
                QualityButton(quality: .paleYellow, isSelected: true, action: {})
                QualityButton(quality: .yellow, isSelected: false, action: {})
                QualityButton(quality: .darkYellow, isSelected: false, action: {})
                QualityButton(quality: .amber, isSelected: false, action: {})
            }
        }
        .padding()
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
        .previewLayout(.sizeThatFits)
    }
} 