//
//  IconChooser.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI
import ElegantEmojiPicker

struct IconInitPage: View {
    let username: String
    
    @EnvironmentObject var appState: AppState
    
    @State private var color: Color = .blue
    @State private var selectedEmoji: Emoji? = Emoji(
        emoji: "😀",
        description: "grinning face",
        category: EmojiCategory.SmileysAndEmotion,
        aliases: ["grinning"],
        tags: ["smile", "happy"],
        supportsSkinTones: false,
        iOSVersion: "6.0"
    )
    @State private var isEmojiPickerPresented: Bool = false
    @State private var isSending: Bool = false
    @State private var showErrorAlert: Bool = false

    var body: some View {
        
        NavigationStack{
            VStack(alignment: .leading) {
                Text("Make your Icon" )
                    .font(.largeTitle)
            
                Text("Select your favorite emoji and color!")
                    .padding(.bottom, 15)
                
                Icon(
                    emoji: selectedEmoji?.emoji ?? "No emoji selected",
                    iconColor: color,
                    active: false
                ).padding(.bottom)
                
                
                HStack()
                {
                    Text("① Emoji:")
                        .font(.title)
                    Button(action: {
                        isEmojiPickerPresented.toggle()
                    }
                    ) {
                        Text("Select")
                            .font(.title2)
                    }
                    .buttonStyle(.borderedProminent)
                    .emojiPicker(
                        isPresented: $isEmojiPickerPresented,
                        selectedEmoji: $selectedEmoji,
                        detents: [.large], // Specify which presentation detents to use for the slide sheet (Optional),
                        configuration: ElegantConfiguration(
                            showSearch: false,
                            showRandom: false,
                            showReset: false,
                            showClose: false
                        ),
                        localization: ElegantLocalization(searchFieldPlaceholder: "絵文字を検索"
                                                         )
                    )
                    .padding(10)
                    
                }

                Text("② Color:")
                    .font(.title)
                ColorPickerGrid(selectedColor: $color)
                
                
                Spacer()
                
                Button {
                    Task{
                        isSending = true
                        if (await updateUser(
                            name: username,
                            iconEmoji: selectedEmoji?.emoji ?? "❓",
                            iconColor: color.toHex() ?? "#FFFFFF"
                        )){
                            appState.status = .home
                        } else {
                            showErrorAlert = true
                        }
                        isSending = false
                    }
                } label : {
                    Group{
                        if !isSending {
                            Text("Done")
                        } else {
                            ProgressView()
                        }
                    }
                    .font(.title2)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.blue)
                .disabled(isSending)
            }
            .padding()
        }
        .alert("Some error occurred", isPresented: $showErrorAlert) {
            Button("Close") {
                showErrorAlert = false
            }
        }
    }
}


#Preview {
    IconInitPage(username: "Taro")
}

