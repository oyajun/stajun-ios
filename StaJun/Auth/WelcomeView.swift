import SwiftUI

struct WelcomeView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo and title
                VStack(spacing: 8) {
                    Text("StaJun")
                        .font(.largeTitle.bold())
                    Text("What are you studying now?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    Button {
                        appState.authState = .anonymousOnboarding
                    } label: {
                        Text("新しく始める")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        appState.authState = .emailLogin
                    } label: {
                        Text("アカウントをお持ちの方はログイン")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                }
                .padding(.horizontal)

                Spacer()
                    .frame(height: 16)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    WelcomeView()
        .environment(AppState())
}
