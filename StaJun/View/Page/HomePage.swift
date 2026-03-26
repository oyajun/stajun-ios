//
//  HomePage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/15.
//

import SwiftUI
import SwiftData
import SimpleKeychain

struct HomePage: View {
    @Binding var studying : Bool
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]
    
    @State private var showFollowModal: Bool = false
    @Environment(\.dismiss) var dismiss
    
    @Query(sort: \User.activityUpdatedAt, order: .reverse) private var followees: [User]
    @State private var me: User? = nil
    @Environment(\.modelContext) private var context
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true){
            HStack(alignment: .center){
                
                HStack(spacing: 20) {
                    VStack(alignment: .center){
                        Icon(emoji: me?.iconEmoji ?? "❓", iconColor: Color(hex: me?.iconColor ?? "#FFFFFF") ?? .blue, active : studying)
                        Text(me?.name ?? "You")
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
                                        _ = await changeActivity(nowStudying: studying)
                                        _ = await setFolloweesActivity(context: context)
                                    }
                                }
                        }
                        Spacer()
                    }
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity)
            
            
            Button("test") {
                do {
                    _ = try myAccountURL()
                } catch {
                    
                }
            }
            
            Text("Studying")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(followees) { followee  in
                    if followee.activityNowStudying {
                        VStack(alignment: .center){
                            Icon(emoji: followee.iconEmoji, iconColor: Color(hex: followee.iconColor) ?? .blue, active : true)
                            Text(followee.name)
                                .lineLimit(1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            
            Text("Not Studying")
                .font(.headline)
                .padding(.top)
            
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(followees) { followee  in
                    if !followee.activityNowStudying {
                        VStack(alignment: .center){
                            Icon(emoji: followee.iconEmoji, iconColor: Color(hex: followee.iconColor) ?? .blue, active : false)
                            Text(followee.name)
                                .lineLimit(1)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            }
            .refreshable {
                Task{
                    await setFolloweesActivity(context: context)
                }
            }
            .onAppear {
                Task{
                    await setFolloweesActivity(context: context)
                }
            }
            .task {
                if let id = getMeId() {
                    let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == id })
                    me = try? context.fetch(descriptor).first
                }
            }
    }
    
    private func getMeId() -> String? {
        let keychain = SimpleKeychain()
        if let data = try? keychain.data(forKey: "userid"),
           let id = String(data: data, encoding: .utf8),
           !id.isEmpty {
            return id
        }
        return nil
    }
}

#Preview {
    @Previewable @State var studying: Bool = false
    HomePage(studying: $studying)
}

