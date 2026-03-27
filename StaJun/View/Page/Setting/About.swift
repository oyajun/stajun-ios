//
//  About.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/27.
//

import SwiftUI
internal import System

struct About: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    var body: some View {
        NavigationStack {
            List () {
                
                Section(header: Text("Version")) {
                    Text("\(version ?? "") (\(build ?? ""))")
                }
                
                
                Section(header: Text("Developer")) {
                    Text("Oyamada Jun")
                    Link("Web Site",
                         destination:
                            URL(string: "https://oyajun.com")!
                    )
                }
                
                Section(header: Text("Source Code")) {
                    Link("Github stajun-ios",
                         destination:
                            URL(string: "https://github.com/oyajun/stajun-ios")!
                    )
                }
                
                Section(header: Text("Licenses")) {
                    NavigationLink("StaJun's License : GPL v3.0") {
                        GPLv3()
                    }
                    NavigationLink("Third Party Licenses") {
                        LicensePage()
                    }
                }
               
            }
        }
        .navigationTitle(Text("About StaJun"))
        
    }
}

#Preview {
    About()
}
