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
            VStack {
                Circle()
                    .fill(quality.color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                    .shadow(color: isSelected ? Color.blue.opacity(0.7) : Color.gray.opacity(0.3), 
                           radius: isSelected ? 4 : 2)
                
                if isSelected {
                    Text(quality.emoji)
                        .font(.system(size: 16))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? quality.color.opacity(0.3) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
struct QualityButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            QualityButton(quality: .clear, isSelected: true, action: {})
            QualityButton(quality: .paleYellow, isSelected: false, action: {})
            QualityButton(quality: .yellow, isSelected: false, action: {})
            QualityButton(quality: .darkYellow, isSelected: false, action: {})
            QualityButton(quality: .amber, isSelected: false, action: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 