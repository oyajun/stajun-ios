//
//  CodeScanner.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/26.
//

import SwiftUI
import CodeScanner
import AVFoundation

struct CodeScanner: View {
    @State var userId : String = ""
    @State var showErrorAlert : Bool = false
    @State var showFollowAlert : Bool = false
    @State var isFollowing : Bool = false
    @State var showFollowedAlert : Bool = false
    @State var showFollowErrorAlert : Bool = false
    
    @State private var scannerId = UUID()

    var body: some View {
        Group{
            CodeScannerView(
                codeTypes: [.qr],
                simulatedData: "Paul Hudson"
            ) { response in
                switch response {
                case .success(let result):
                    do {
                        userId = try decodeURL(urlString: result.string)
                        //showErrorAlert = true
                        print("成功")
                        print(userId)
                        showFollowAlert = true
                    } catch {
                        userId = ""
                        print("失敗")
                        showErrorAlert = true
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
            .id(scannerId)
        }
        .alert("Invalid QR Code", isPresented: $showErrorAlert) {
            Button("Close") {
                scannerId = UUID()
            }
        }
        .alert("Do you want to follow?", isPresented: $showFollowAlert) {
            Button() {
                Task {
                    isFollowing = true
                    if await follow(userId: userId) {
                        isFollowing = false
                        showFollowAlert = false
                        showFollowedAlert = true
                    } else {
                        isFollowing = false
                        showFollowAlert = false
                        showFollowErrorAlert = true
                    }
                }
            } label: {
                if isFollowing {
                    ProgressView()
                } else {
                    Text("Follow")
                }
            }
            .disabled(isFollowing)
            Button("Cancel", role: .cancel){
                showFollowAlert = false
                scannerId = UUID()
            }.disabled(isFollowing)
        }
        .alert("Sucsess to Follow", isPresented: $showFollowedAlert) {
            Button("OK"){
                scannerId = UUID()
            }
        }
        .alert("Unable to follow", isPresented: $showFollowErrorAlert) {
            Button("Close"){
                scannerId = UUID()
            }
        }
    }
}

#Preview {
    CodeScanner()
}
