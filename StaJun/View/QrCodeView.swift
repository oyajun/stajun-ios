//
//  QrCodeView.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//
// https://zenn.dev/slowhand/articles/3c53b230229054

import CoreImage.CIFilterBuiltins
import SwiftUI

struct QrCodeView: View {
    var data: String
    var body: some View {
        Image(uiImage: qrImage)
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .accessibilityLabel(Text("QRCode"))
    }

    private var qrImage: UIImage {
        let qrCodeGenerator = CIFilter.qrCodeGenerator()
        qrCodeGenerator.message = Data(data.utf8)
        qrCodeGenerator.correctionLevel = "H"
        if let outputimage = qrCodeGenerator.outputImage {
            if let cgImage = CIContext().createCGImage(
                outputimage, from: outputimage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return UIImage()
    }
}

#Preview {
    QrCodeView(data: "abc")
        .frame(width: 150, height: 150)
}
