//
//  ErrorAlert.swift
//  StaJun
//
//  Created by 小山田純 on 2026/03/25.
//

import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    @EnvironmentObject var appState: AppState
    
    @Binding var isPresented: Bool
    
    let error: APIError

    func body(content: Content) -> some View {
        content
            .alert(title(for: error), isPresented: $isPresented, presenting: error) { error in
                if case .unauthorized = error {
                    Button("Log out", role: .destructive) {
                        Task {
                            let _ = await signOut()
                            appState.status = .signIn
                        }
                    }
                }
                Button("Close", role: .cancel) {}
            } message: { error in
                Text(message(for: error))
            }
    }

    private func title(for error: APIError) -> String {
        switch error {
        case .unauthorized: return "Authentication Failed"
        case .networkError(let urlError):
            switch urlError.code {
            case .notConnectedToInternet: return "No Internet Connection"
            case .timedOut: return "Request Timed Out"
            default: return "Network Error Occurred"
            }
        case .clientError(let code): return "Request Error (\(code))"
        case .serverError(let code): return "Server Error (\(code))"
        case .decodingError: return "Data Parsing Error"
        default: return "Unknown Error Occurred"
        }
    }
    
    private func message(for error: APIError) -> String {
        switch error {
        case .unauthorized: return "Please log in again"
        case .networkError(let urlError):
            switch urlError.code {
            case .notConnectedToInternet: return "Check your mobile data or WiFi settings"
            case .timedOut: return "Please try again"
            default: return ""
            }
        case .clientError(_): return ""
        case .serverError(_): return "Please try again later"
        case .decodingError: return ""
        default: return ""
        }
    }
}

extension View {
    func errorAlert(isPresented: Binding<Bool>, error: APIError) -> some View {
        self.modifier(ErrorAlertModifier(isPresented: isPresented, error: error))
    }
}

#Preview("notConnectedToInternet") {
    VStack {
        Text("プレビュー用ビュー")
            .padding()
    }
    .errorAlert(
        isPresented: .constant(true),
        error: .networkError(URLError(.notConnectedToInternet))
    )
}

#Preview("unauthorized") {
    VStack {
        Text("プレビュー用ビュー")
            .padding()
    }
    .errorAlert(
        isPresented: .constant(true),
        error: .unauthorized
    )
}
