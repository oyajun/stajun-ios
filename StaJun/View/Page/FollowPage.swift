//
//  FollowPage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import SwiftUI
import VisionKit
internal import Vision

struct QRCodeScanner: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let dataScannerViewController = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            isHighlightingEnabled: true
        )
        try? dataScannerViewController.startScanning()
        return dataScannerViewController
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
    }
}

struct FollowPage: View {
    @State private var selected: Int = 0
    
    var body: some View {
        
        VStack {
            Picker("", selection: $selected) {
                Text("Your QR Code").tag(0)
                Text("Scan frined's QR Code").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            if selected == 0 {
                Spacer()
                Text("Scan this code on your friend's phone")
                    .font(.title2)
                QrCodeView(data: "oyajun")
                Spacer()
            } else {
                QRCodeScanner()
            }
        }
    }
}

#Preview {
    FollowPage()
}
