import SwiftUI

struct ProfileSetupView: View {
    var isAnonymous: Bool = false

    var body: some View {
        EditProfileView(mode: .create(isAnonymous: isAnonymous))
    }
}

#Preview {
    ProfileSetupView()
        .environment(AppState())
}
