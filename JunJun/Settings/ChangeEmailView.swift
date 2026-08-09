import SwiftUI

struct ChangeEmailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showOTP = false
    @State private var targetEmail = ""
    
    var body: some View {
        NavigationStack {
            EmailInputView(
                mode: .changeEmail,
                onSuccess: { email in
                    targetEmail = email
                    showOTP = true
                }
            )
            .navigationDestination(isPresented: $showOTP) {
                OTPInputView(
                    email: targetEmail,
                    mode: .changeEmail,
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
