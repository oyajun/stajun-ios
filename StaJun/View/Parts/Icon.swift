//
//  Icon.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI

struct Icon: View {
    let emoji: String
    let iconColor: Color
    let active: Bool

    var body: some View {
        ZStack (alignment: .center){
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            iconColor,
                            iconColor.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: 80, height: 80)
                .shadow(
                    color: active ? .green : .black.opacity(0.2),
                    radius: 10,
                    x: 0,
                    y: 2,
                )
            Text(String(emoji))
                .font(.system(size: 55))
                .shadow(color: .white, radius: 2)
        }
    }
}

#Preview("Icon active") {
    Icon(emoji: "❤️", iconColor: .red, active: true)
}

#Preview("Icon inactive") {
    Icon(emoji: "❤️", iconColor: .red, active: false)
}
