import SwiftUI

struct ChangeEmailView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showOTP = false
    @State private var targetEmail = ""

    private var mode: AuthFlowMode {
        appState.userEmail == nil ? .registerEmail : .changeEmail
    }
    
    var body: some View {
        NavigationStack {
            EmailInputView(
                mode: mode,
                onSuccess: { email in
                    targetEmail = email
                    showOTP = true
                }
            )
            .navigationDestination(isPresented: $showOTP) {
                OTPInputView(
                    email: targetEmail,
                    mode: mode,
                    onSuccess: {
                        dismiss()
                    },
                    onCancel: {
                        dismiss() // This cancels the whole modal
                    }
                )
            }
        }
    }
}

#Preview {
    ChangeEmailView()
        .environment(AppState())
}
