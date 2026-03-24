//
//  HomePage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI

struct HomePage: View {
    @Binding var studying : Bool
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    @State private var showFollowModal: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true){
            HStack(alignment: .center){
                
                HStack(spacing: 20) {
                    VStack(alignment: .center){
                        Icon(emoji: "🍅", iconColor: .pink, active : studying)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    
                
                    VStack(alignment: .trailing){
                        Button{
                            showFollowModal = true
                        } label: {
                            Label("Add Friends", systemImage: "person.badge.plus")
                        }.sheet(isPresented: $showFollowModal) {
                            NavigationStack {
                                FollowPage()
                            }
                        }
                        Spacer()
                        HStack{
                            Text("Studying")
                                .font(.title)
                                .bold()
                                .padding(.trailing)
                            Toggle("", isOn: $studying)
                                .labelsHidden()
                                .scaleEffect(1.3)
                                .padding(.trailing)
                                .onChange(of: studying) {
                                    // 楽観的UI
                                    Task{
                                        await changeActivity(nowStudying: studying)
                                    }
                                }
                        }
                        Spacer()
                    }
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity)
            
            
            Text("Studying")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 20) {
                VStack(alignment: .center){
                    Icon(emoji: "⭐️", iconColor: .red, active : true)
                    Text("じゅげむじゅげむじゅげむじゅげむじゅげむじゅげむじゅげむじゅげむじゅげむじゅげむじゅげむじゅげむ")
                        .lineLimit(1)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .center){
                    Icon(emoji: "🫛", iconColor: .red, active : true)
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                VStack(alignment: .center){
                    Icon(emoji: "🫛", iconColor: .red, active : true)
                    Text("You")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            Text("Not Studying")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: columns, spacing: 20) {
                
                    VStack(alignment: .center){
                        Icon(emoji: "🏯", iconColor: .red, active : false)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .center){
                        Icon(emoji: "🫛", iconColor: .red, active : false)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .center){
                        Icon(emoji: "🫛", iconColor: .red, active : false)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .center){
                        Icon(emoji: "🫛", iconColor: .red, active : false)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .center){
                        Icon(emoji: "🫛", iconColor: .red, active : false)
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                }
                .padding()
                
            }
            .refreshable {
                // TODO 更新コード
            }
            
        }
}

#Preview {
    @Previewable @State var studying: Bool = false
    HomePage(studying: $studying)
}
