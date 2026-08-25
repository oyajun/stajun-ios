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
    @State private var isReregistering = false
    @State private var errorMessage: String?
    @State private var errorAlertTitle: LocalizedStringKey = "Could Not Update Settings"
    @State private var showErrorAlert = false
    @State private var showSuccessAlert = false

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
            } footer: {
                Text("To turn off notifications for a specific user you follow, you can mute them individually from their profile.")
            }

            // プッシュ通知の再登録
            Section {
                Button {
                    reregisterPushNotifications()
                } label: {
                    HStack {
                        Text("Re-register Push Notifications")
                            .foregroundStyle(isReregistering ? .secondary : .primary)
                        Spacer()
                        if isReregistering {
                            ProgressView()
                        }
                    }
                }
                .disabled(isReregistering)
            } footer: {
                Text("If you are not receiving push notifications, try re-registering.")
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
        .alert(errorAlertTitle, isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            } else {
                Text("An unexpected error occurred. Please try again.")
            }
        }
        .alert("Push Notifications Re-registered", isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your device has been re-registered to receive push notifications.")
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
                    self.errorAlertTitle = "Could Not Update Settings"
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                }
            }
        }
    }

    private func reregisterPushNotifications() {
        guard !isReregistering else { return }
        isReregistering = true

        Task {
            defer {
                Task { @MainActor in
                    self.isReregistering = false
                }
            }

            do {
                try await NotificationHandler.reregister()
                await checkSystemNotificationStatus()
                await MainActor.run {
                    self.showSuccessAlert = true
                }
            } catch let error as NotificationHandler.RegistrationError where error == .permissionDenied {
                await checkSystemNotificationStatus()
                await MainActor.run {
                    self.errorAlertTitle = "Notifications Disabled"
                    self.errorMessage = String(localized: "Push notifications are turned off in your device settings. To receive notifications, please allow notifications for JunJun in Settings.")
                    self.showErrorAlert = true
                }
            } catch {
                await MainActor.run {
                    self.errorAlertTitle = "Could Not Re-register"
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
