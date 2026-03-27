//
//  LicensePage.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/27.
//

import SwiftUI
import LicenseList

struct LicensePage: View {
    var body: some View {
        NavigationView {
            LicenseListView()
                // If you want to anchor link of the repository
                .licenseViewStyle(.withRepositoryAnchorLink)
                
        }
        .navigationTitle("Third Party Licenses")
    }
}

#Preview {
    LicensePage()
}
