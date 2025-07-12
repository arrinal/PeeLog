//
//  ViewModifiers.swift
//  PeeLog
//
//  Created by Arrinal S on 25/06/25.
//

import SwiftUI

// MARK: - Card Styling
struct CardModifier: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOpacity: Double
    @Environment(\.colorScheme) private var colorScheme
    
    init(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 8,
        shadowOpacity: Double = 0.1
    ) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(
                        color: colorScheme == .dark ? 
                            Color.white.opacity(shadowOpacity * 0.5) : 
                            Color.black.opacity(shadowOpacity), 
                        radius: shadowRadius, 
                        x: 0, 
                        y: 2
                    )
            )
    }
}

// MARK: - Typography Styles
struct TitleStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    
    init(size: CGFloat = 28, weight: Font.Weight = .bold, design: Font.Design = .rounded) {
        self.size = size
        self.weight = weight
        self.design = design
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight, design: design))
            .foregroundColor(.primary)
    }
}

struct SubtitleStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    
    init(size: CGFloat = 16, weight: Font.Weight = .medium) {
        self.size = size
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .foregroundColor(.secondary)
    }
}

struct HeadlineStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    
    init(size: CGFloat = 20, weight: Font.Weight = .semibold) {
        self.size = size
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .foregroundColor(.primary)
    }
}

struct BodyStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    
    init(size: CGFloat = 14, weight: Font.Weight = .regular) {
        self.size = size
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .foregroundColor(.primary)
    }
}

struct CaptionStyle: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight
    
    init(size: CGFloat = 12, weight: Font.Weight = .medium) {
        self.size = size
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .foregroundColor(.secondary)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ViewModifier {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(foregroundColor)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(backgroundColor)
                    .shadow(color: backgroundColor.opacity(0.4), radius: 8, x: 0, y: 4)
            )
    }
}

struct SecondaryButtonStyle: ViewModifier {
    let backgroundColor: Color
    let foregroundColor: Color
    let cornerRadius: CGFloat
    let padding: EdgeInsets
    
    init(
        backgroundColor: Color = Color.blue.opacity(0.1),
        foregroundColor: Color = .blue,
        cornerRadius: CGFloat = 12,
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(foregroundColor)
            .padding(padding)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }
}

// MARK: - Badge Styles
struct BadgeStyle: ViewModifier {
    let backgroundColor: Color
    let foregroundColor: Color
    let size: CGFloat
    let weight: Font.Weight
    
    init(
        backgroundColor: Color,
        foregroundColor: Color = .white,
        size: CGFloat = 12,
        weight: Font.Weight = .medium
    ) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.size = size
        self.weight = weight
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: weight))
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
    }
}

// MARK: - View Extensions
extension View {
    // Card styling
    func cardStyle(
        backgroundColor: Color = Color(.systemBackground),
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 8,
        shadowOpacity: Double = 0.1
    ) -> some View {
        self.modifier(CardModifier(
            backgroundColor: backgroundColor,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            shadowOpacity: shadowOpacity
        ))
    }
    
    // Typography
    func titleStyle(size: CGFloat = 28, weight: Font.Weight = .bold, design: Font.Design = .rounded) -> some View {
        self.modifier(TitleStyle(size: size, weight: weight, design: design))
    }
    
    func subtitleStyle(size: CGFloat = 16, weight: Font.Weight = .medium) -> some View {
        self.modifier(SubtitleStyle(size: size, weight: weight))
    }
    
    func headlineStyle(size: CGFloat = 20, weight: Font.Weight = .semibold) -> some View {
        self.modifier(HeadlineStyle(size: size, weight: weight))
    }
    
    func bodyStyle(size: CGFloat = 14, weight: Font.Weight = .regular) -> some View {
        self.modifier(BodyStyle(size: size, weight: weight))
    }
    
    func captionStyle(size: CGFloat = 12, weight: Font.Weight = .medium) -> some View {
        self.modifier(CaptionStyle(size: size, weight: weight))
    }
    
    // Button styling
    func primaryButtonStyle(
        backgroundColor: Color = .blue,
        foregroundColor: Color = .white,
        cornerRadius: CGFloat = 16,
        padding: EdgeInsets = EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
    ) -> some View {
        self.modifier(PrimaryButtonStyle(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            cornerRadius: cornerRadius,
            padding: padding
        ))
    }
    
    func secondaryButtonStyle(
        backgroundColor: Color = Color.blue.opacity(0.1),
        foregroundColor: Color = .blue,
        cornerRadius: CGFloat = 12,
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
    ) -> some View {
        self.modifier(SecondaryButtonStyle(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            cornerRadius: cornerRadius,
            padding: padding
        ))
    }
    
    // Badge styling
    func badgeStyle(
        backgroundColor: Color,
        foregroundColor: Color = .white,
        size: CGFloat = 12,
        weight: Font.Weight = .medium
    ) -> some View {
        self.modifier(BadgeStyle(
            backgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            size: size,
            weight: weight
        ))
    }
    
    // Quality badge - specific to PeeLog
    func qualityBadgeStyle(quality: PeeQuality) -> some View {
        self.badgeStyle(backgroundColor: quality.color)
    }
} 