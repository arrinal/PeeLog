//
//  ConnectivityToast.swift
//  PeeLog
//

import SwiftUI

struct ConnectivityToast: View {
    let text: String
    let background: Color
    
    var body: some View {
        ZStack {
            background
                .ignoresSafeArea(edges: .top)
            HStack(spacing: 10) {
                Image(systemName: background == .red ? "wifi.slash" : "wifi")
                    .font(.headline)
                Text(text)
                    .font(.callout)
                    .fontWeight(.semibold)
                Spacer(minLength: 0)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}



