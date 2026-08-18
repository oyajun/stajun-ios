import SwiftUI
import UserNotifications

struct PushNotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var settings: PushNotificationSettings = PushNotificationSettings(
        enabled: true,
        follow: true,
        studyStart: true
    )
    @State private var isLoading = true
    @State private var isSystemNotificationDisabled = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        Form {
            // 端末の通知設定がオフの場合の警告セクション
            if isSystemNotificationDisabled {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                            Text("Notifications Disabled")
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Text("Push notifications are turned off in your device settings. To receive notifications, please allow notifications for JunJun in Settings.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button {
                            openAppSettings()
                        } label: {
                            HStack {
                                Text("Open Settings")
                                    .fontWeight(.semibold)
                                Image(systemName: "arrow.up.forward.app")
                            }
                            .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }

            // プッシュ通知マスタースイッチ
            Section {
                Toggle("Push Notifications", isOn: Binding(
                    get: { settings.enabled },
                    set: { newValue in
                        updateSetting(enabled: newValue)
                    }
                ))
            } footer: {
                Text("Turning this off pauses all push notifications. In-app notifications will still appear in the Notifications tab.")
            }

            // 個別通知設定
            Section {
                Toggle("Follows", isOn: Binding(
                    get: { settings.follow },
                    set: { newValue in
                        updateSetting(follow: newValue)
                    }
                ))
                .disabled(!settings.enabled)
                .foregroundStyle(settings.enabled ? .primary : .secondary)

                Toggle("Study Start from Following", isOn: Binding(
                    get: { settings.studyStart },
                    set: { newValue in
                        updateSetting(studyStart: newValue)
                    }
                ))
                .disabled(!settings.enabled)
                .foregroundStyle(settings.enabled ? .primary : .secondary)
            } header: {
                Text("Activity")
            }
        }
        .navigationTitle("Push Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await loadSettings()
            await checkSystemNotificationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await checkSystemNotificationStatus()
                }
            }
        }
        .alert("Could Not Update Settings", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            } else {
                Text("An unexpected error occurred. Please try again.")
            }
        }
    }

    // MARK: - Actions

    private func checkSystemNotificationStatus() async {
        let center = UNUserNotificationCenter.current()
        let notificationSettings = await center.notificationSettings()
        await MainActor.run {
            isSystemNotificationDisabled = (notificationSettings.authorizationStatus == .denied)
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func loadSettings() async {
        do {
            let fetched = try await APIClient.getPushNotificationSettings()
            await MainActor.run {
                self.settings = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func updateSetting(
        enabled: Bool? = nil,
        follow: Bool? = nil,
        studyStart: Bool? = nil
    ) {
        let previous = settings

        // 楽観的UI更新
        if let enabled { settings.enabled = enabled }
        if let follow { settings.follow = follow }
        if let studyStart { settings.studyStart = studyStart }

        Task {
            do {
                let updated = try await APIClient.updatePushNotificationSettings(
                    enabled: enabled,
                    follow: follow,
                    studyStart: studyStart
                )
                await MainActor.run {
                    self.settings = updated
                }
            } catch {
                await MainActor.run {
                    // ロールバック
                    self.settings = previous
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PushNotificationSettingsView()
    }
}
