//
//  Color.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import SwiftUI

extension Color {
    func toHex() -> String? {
        let uiColor = UIColor(self)

        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }

        let rInt = Int(r * 255)
        let gInt = Int(g * 255)
        let bInt = Int(b * 255)

        return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)

        guard let int = UInt64(hex, radix: 16) else { return nil }

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}
