//
//  FollowPage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/24.
//

import SwiftUI

struct FollowPage: View {
    @State private var selected: Int = 0
    @Environment(\.dismiss) var dismiss
    @State private var myurl: String = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selected) {
                    Text("Your QR Code").tag(0)
                    Text("Scan frined's QR Code").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()

                if selected == 0 {
                    
                    Spacer()
                    
                        .font(.title2)
                    Group(){
                        if (myurl.isEmpty) {
                            Text("Uneable to display your QR Code")
                        } else {
                            Text("Scan this code in your friend's Stajun App")
                            QrCodeView(data: myurl)
                        }
                    }
                    .padding(30)
                    Spacer()
                } else {
                    CodeScanner()
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            do {
                myurl = try myAccountURL().absoluteString
            } catch {
                myurl = ""
            }
        }
    }
        
}

#Preview {
    FollowPage()
}
