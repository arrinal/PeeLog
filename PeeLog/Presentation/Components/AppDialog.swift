//
//  AppDialog.swift
//  PeeLog
//
//  Created by Assistant on 12/08/25.
//

import SwiftUI

// MARK: - Dialog Button Style
// Use unique names to avoid clashing with existing modifiers
private struct DialogPrimaryButtonVisual: ViewModifier {
    let isDestructive: Bool
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                Group {
                    if isDestructive {
                        Color.red
                    } else {
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.cyan]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .cornerRadius(12)
    }
}

private struct DialogSecondaryButtonVisual: ViewModifier {
    let isDestructive: Bool
    func body(content: Content) -> some View {
        let textColor: Color = isDestructive ? .red : .blue
        let background: Color = isDestructive ? Color.red.opacity(0.1) : Color.blue.opacity(0.1)
        return content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(background)
            .cornerRadius(12)
    }
}

// MARK: - Core Dialog View
private struct AppDialogCard: View {
    let title: String
    let message: String
    let iconSystemName: String?
    let primaryTitle: String
    let primaryDestructive: Bool
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let secondaryDestructive: Bool
    let onSecondary: (() -> Void)?
    let showsClose: Bool
    let onClose: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 12) {
                if let iconSystemName {
                    Image(systemName: iconSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.blue)
                }
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if showsClose {
                    Button(action: { onClose?() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
            
            // Message
            ScrollView {
                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 140)
            
            // Actions
            VStack(spacing: 10) {
                Button(action: onPrimary) {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .modifier(DialogPrimaryButtonVisual(isDestructive: primaryDestructive))
                
                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(DialogSecondaryButtonVisual(isDestructive: secondaryDestructive))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 6)
        )
    }
}

// MARK: - Modifiers
private struct AppAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let iconSystemName: String
    let primaryTitle: String
    let onPrimary: () -> Void
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
                    .onTapGesture { }
                AppDialogCard(
                    title: title,
                    message: message,
                    iconSystemName: iconSystemName,
                    primaryTitle: primaryTitle,
                    primaryDestructive: false,
                    onPrimary: {
                        isPresented = false
                        onPrimary()
                    },
                    secondaryTitle: nil,
                    secondaryDestructive: false,
                    onSecondary: nil,
                    showsClose: true,
                    onClose: { isPresented = false }
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPresented)
    }
}

private struct AppConfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let iconSystemName: String
    let primaryTitle: String
    let primaryDestructive: Bool
    let onPrimary: () -> Void
    let secondaryTitle: String
    let secondaryDestructive: Bool
    let onSecondary: () -> Void
    let showsClose: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
                    .onTapGesture { }
                AppDialogCard(
                    title: title,
                    message: message,
                    iconSystemName: iconSystemName,
                    primaryTitle: primaryTitle,
                    primaryDestructive: primaryDestructive,
                    onPrimary: {
                        isPresented = false
                        onPrimary()
                    },
                    secondaryTitle: secondaryTitle,
                    secondaryDestructive: secondaryDestructive,
                    onSecondary: {
                        isPresented = false
                        onSecondary()
                    },
                    showsClose: showsClose,
                    onClose: { if showsClose { isPresented = false } }
                )
                .padding(.horizontal, 24)
                .transition(.scale.combined(with: .opacity))
                .zIndex(2)
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isPresented)
    }
}

// MARK: - View Extensions
extension View {
    func appAlert(isPresented: Binding<Bool>, title: String, message: String, iconSystemName: String = "exclamationmark.triangle.fill", primaryTitle: String = "OK", onPrimary: @escaping () -> Void = {}) -> some View {
        modifier(AppAlertModifier(isPresented: isPresented, title: title, message: message, iconSystemName: iconSystemName, primaryTitle: primaryTitle, onPrimary: onPrimary))
    }
    
    func appConfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        iconSystemName: String = "exclamationmark.triangle.fill",
        primaryTitle: String,
        primaryDestructive: Bool = false,
        onPrimary: @escaping () -> Void,
        secondaryTitle: String,
        secondaryDestructive: Bool = false,
        onSecondary: @escaping () -> Void,
        allowsClose: Bool = true
    ) -> some View {
        modifier(AppConfirmModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            iconSystemName: iconSystemName,
            primaryTitle: primaryTitle,
            primaryDestructive: primaryDestructive,
            onPrimary: onPrimary,
            secondaryTitle: secondaryTitle,
            secondaryDestructive: secondaryDestructive,
            onSecondary: onSecondary,
            showsClose: allowsClose
        ))
    }
}


