//
//  SwiftUIView.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI

struct ColorPickerGrid: View {

    let colors: [Color] = [
        .red, .orange, .yellow, .green,
        .mint, .teal, .cyan, .blue,
        .indigo, .purple, .pink,
        .brown, .gray, .black
    ]

    @Binding var selectedColor: Color

    let columns = [GridItem(.adaptive(minimum: 40))]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(colors.indices, id: \.self) { i in
                Button {
                    selectedColor = colors[i]
                } label: {
                    Circle()
                        .fill(colors[i])
                        .frame(width: 36)
                        .overlay(
                            Circle().stroke(.gray.opacity(0.3))
                        )
                }
            }
        }
    }
}

#Preview {
    ColorPickerGrid(
        selectedColor: .constant(.blue)
    )
}
