import SwiftUI

extension View {
    func errorAlert(errorMessage: Binding<String?>) -> some View {
        alert("Error", isPresented: Binding(
            get: { errorMessage.wrappedValue != nil },
            set: { if !$0 { errorMessage.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = errorMessage.wrappedValue {
                Text(message)
            }
        }
    }
}
