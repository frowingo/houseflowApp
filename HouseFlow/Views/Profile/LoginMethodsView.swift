import HouseFlowCore
import SwiftUI

/// Settings → "Sign-in methods": which providers are linked, link/unlink, and setting a password.
struct LoginMethodsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var busyProvider: SocialProvider?
    @State private var message: String?
    @State private var messageIsInfo = false
    @State private var showSetPassword = false

    private var store: AuthSessionStore { appViewModel.socialAuthStore }
    private var profile: IsAuthUserData? { appViewModel.currentUserProfile }
    private var linked: Set<SocialProvider> {
        Set((profile?.linkedProviders ?? []).compactMap(SocialProvider.init(rawValue:)))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(rows, id: \.self) { provider in
                        providerRow(provider)
                    }
                }
                if profile?.hasPassword == false {
                    Section {
                        Button(appViewModel.social("login_methods_set_password", tr: "Şifre belirle", en: "Set a password")) {
                            showSetPassword = true
                        }
                    } footer: {
                        Text(appViewModel.social(
                            "login_methods_set_password_hint",
                            tr: "Emailine bir kod göndeririz; şifreni o kodla belirlersin.",
                            en: "We'll email you a code that lets you choose a password."
                        ))
                    }
                }
                if let message {
                    Section {
                        Text(message).foregroundColor(messageIsInfo ? AppDesign.Colors.text : AppDesign.Colors.error)
                    }
                }
            }
            .navigationTitle(appViewModel.social("profile_login_methods_label", tr: "Giriş yöntemleri", en: "Sign-in methods"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(appViewModel.localized("common_done", fallback: "Done")) { dismiss() }
                }
            }
            .task { await store.refreshAccountMethods() }
            .fullScreenCover(isPresented: $showSetPassword) { ForgotPasswordView() }
        }
    }

    /// Providers that are linked, plus enabled ones the user could link.
    private var rows: [SocialProvider] {
        SocialProvider.signInProviders.filter { linked.contains($0) || store.shownSocialProviders.contains($0) }
    }

    private func providerRow(_ provider: SocialProvider) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name(of: provider))
                Text(linked.contains(provider)
                     ? appViewModel.social("login_methods_linked", tr: "Bağlı", en: "Linked")
                     : appViewModel.social("login_methods_not_linked", tr: "Bağlı değil", en: "Not linked"))
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(AppDesign.Colors.textSecondary)
            }
            Spacer()
            if busyProvider == provider {
                ProgressView()
            } else if linked.contains(provider) {
                Button(appViewModel.social("login_methods_unlink", tr: "Kaldır", en: "Remove"), role: .destructive) {
                    Task { await unlink(provider) }
                }
            } else {
                Button(appViewModel.social("login_methods_link", tr: "Bağla", en: "Link")) {
                    Task { await link(provider) }
                }
            }
        }
        .disabled(busyProvider != nil && busyProvider != provider)
    }

    private func name(of provider: SocialProvider) -> String {
        switch provider {
        case .google: return "Google"
        case .apple: return "Apple"
        case .facebook: return "Facebook"
        case .snapchat: return "Snapchat"
        case .email: return appViewModel.localized("auth_email_label")
        }
    }

    // MARK: - Actions

    private func link(_ provider: SocialProvider) async {
        busyProvider = provider
        message = nil
        messageIsInfo = false
        defer { busyProvider = nil }
        do {
            if try await store.linkSocialProvider(provider) == false { appViewModel.logout() }
        } catch {
            message = error.message
            messageIsInfo = error.isInfo
        }
    }

    private func unlink(_ provider: SocialProvider) async {
        busyProvider = provider
        message = nil
        messageIsInfo = false
        defer { busyProvider = nil }
        do {
            if try await store.unlinkSocialProvider(provider) == false { appViewModel.logout() }
        } catch {
            // 409: the only way in. Suggest a password or another provider first.
            message = error.statusCode == 409
                ? error.message + " " + appViewModel.social(
                    "login_methods_only_method_hint",
                    tr: "Önce şifre belirle ya da başka bir yöntem bağla.",
                    en: "Set a password or link another method first."
                )
                : error.message
        }
    }
}
