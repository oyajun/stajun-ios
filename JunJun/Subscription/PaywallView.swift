import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showSuccessAlert = false
    @State private var showManageSubscriptionsSheet = false

    private var sampleEmoji: String {
        appState.currentUser?.iconEmoji ?? "📚"
    }

    private var sampleBgColor: String {
        appState.currentUser?.iconBackgroundColor ?? "#FFD54F"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Header & Badge (No glow)
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                                .frame(width: 72, height: 72)
                                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)

                            Image(systemName: "crown.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.top, 12)

                        Text("JunJun Pro")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    // MARK: - Features List
                    VStack(spacing: 12) {
                        featureRow(
                            icon: "nosign",
                            iconColor: .red,
                            title: "Hide Ads",
                            description: "No ads are displayed in the app."
                        )

                        // Feature 2: Rainbow Animation + Attached Comparison
                        VStack(spacing: 14) {
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.orange)
                                    .frame(width: 36, height: 36)
                                    .background(Color.orange.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Rainbow Icon")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)

                                    Text("During study, your icon and screen border glow in rainbow colors.\nFriends will also see it in rainbow colors.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }

                            // Icon Comparison: Free -> Pro
                            VStack(spacing: 8) {
                                // Top row: Icons & Arrow (perfect vertical & horizontal centering)
                                HStack(spacing: 18) {
                                    UserIconView(
                                        emoji: sampleEmoji,
                                        backgroundColor: sampleBgColor,
                                        size: 48,
                                        isStudying: true,
                                        isPro: false
                                    )

                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(.tertiary)

                                    UserIconView(
                                        emoji: sampleEmoji,
                                        backgroundColor: sampleBgColor,
                                        size: 48,
                                        isStudying: true,
                                        isPro: true
                                    )
                                }

                                // Bottom row: Labels
                                HStack(spacing: 18) {
                                    Text("Free")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 48)

                                    Image(systemName: "arrow.right")
                                        .font(.subheadline.weight(.bold))
                                        .opacity(0)

                                    HStack(spacing: 3) {
                                        Image(systemName: "crown.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.orange)
                                        Text("JunJun Pro")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.primary)
                                    }
                                    .fixedSize()
                                    .frame(width: 48)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 4)
                            .padding(.bottom, 2)
                        }
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 4)

                    // MARK: - Plan Card
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Monthly Plan")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.primary)

                                Text("Cancel anytime in App Store")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Text(subscriptionManager.localizedPriceString + " / " + String(localized: "month"))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .padding(18)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                        )
                    }

                    // MARK: - Action Buttons
                    VStack(spacing: 12) {
                        if subscriptionManager.isPro || appState.isPro {
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("You are a JunJun Pro Member")
                                        .font(.headline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.green.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                Button {
                                    showManageSubscriptionsSheet = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("Manage Subscription")
                                            .font(.headline.weight(.semibold))

                                        Spacer()

                                        Text("App Store")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)

                                Link(destination: Config.appleRefundURL) {
                                    HStack(spacing: 8) {
                                        Text("Request Refund")
                                            .font(.headline.weight(.semibold))

                                        Spacer()

                                        Text("Apple")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "arrow.up.right")
                                            .font(.footnote.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        } else if subscriptionManager.isAlternativeMarketplace {
                            VStack(spacing: 14) {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.title3)

                                    Text("Purchases are not available because this app was installed from an alternative app marketplace. Please install the app from the App Store.")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                if let appStoreURL = Config.appStoreURL {
                                    Link(destination: appStoreURL) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.down.app.fill")
                                            Text("Install from App Store")
                                                .font(.headline.weight(.bold))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(Color.accentColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            Button {
                                Task { await purchase() }
                            } label: {
                                HStack(spacing: 8) {
                                    if subscriptionManager.isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Start JunJun Pro")
                                            .font(.headline.weight(.bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
                            }
                            .buttonStyle(.plain)
                            .disabled(subscriptionManager.isPurchasing || subscriptionManager.isRestoring)

                            Button {
                                Task { await restore() }
                            } label: {
                                HStack(spacing: 6) {
                                    if subscriptionManager.isRestoring {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text("Restore Purchases")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .disabled(subscriptionManager.isPurchasing || subscriptionManager.isRestoring)
                        }
                    }

                    // MARK: - Legal / Terms & Privacy
                    VStack(spacing: 10) {
                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        VStack(spacing: 8) {
                            HStack(spacing: 16) {
                                Link("Terms of Service", destination: Config.termsOfServiceURL)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)

                                Text("•")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Link("Privacy Policy", destination: Config.privacyPolicyURL)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                            }

                            Link("Specified Commercial Transactions Act", destination: Config.tokushohoURL)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Success", isPresented: $showSuccessAlert) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Welcome to JunJun Pro!")
            }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptionsSheet)
            .task {
                await subscriptionManager.fetchOfferings()
            }
        }
    }

    private func featureRow(icon: String, iconColor: Color, title: LocalizedStringKey, description: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func purchase() async {
        let success = await subscriptionManager.purchasePro()
        if success {
            showSuccessAlert = true
        } else if let err = subscriptionManager.errorMessage {
            errorMessage = err
            showErrorAlert = true
        }
    }

    private func restore() async {
        let success = await subscriptionManager.restorePurchases()
        if success {
            showSuccessAlert = true
        } else if let err = subscriptionManager.errorMessage {
            errorMessage = err
            showErrorAlert = true
        } else {
            errorMessage = String(localized: "No active subscription found to restore.")
            showErrorAlert = true
        }
    }
}

#Preview {
    PaywallView()
}
