import SwiftUI

/// App Store 5.1.1(v): in-app account deletion with an explicit confirmation.
struct DeleteAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var isDeleting = false
    @State private var errorMessage: String?
    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(AppDesign.Colors.error)
            Text(appViewModel.social("delete_account_title", tr: "Hesabı sil", en: "Delete account"))
                .font(AppDesign.Typography.title2)
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                bullet(appViewModel.social("delete_account_permanent",
                                           tr: "Hesabın kalıcı olarak silinir.",
                                           en: "Your account is deleted permanently."))
                bullet(appViewModel.social("delete_account_sole_member",
                                           tr: "Tek üyesi olduğun evler; tüm görevleri, duyuruları ve geçmişiyle birlikte silinir.",
                                           en: "Houses where you are the only member are deleted with all their chores, announcements and history."))
                bullet(appViewModel.social("delete_account_shared",
                                           tr: "Paylaşılan evler kalan ilk üyeye geçer.",
                                           en: "Shared houses pass to the first remaining member."))
            }
            .font(AppDesign.Typography.subheadline)
            if let errorMessage {
                Text(errorMessage).foregroundColor(AppDesign.Colors.error)
            }
            Spacer()
            Button(role: .destructive) { confirming = true } label: {
                ZStack {
                    if isDeleting { ProgressView() } else {
                        Text(appViewModel.social("delete_account_button", tr: "Hesabımı kalıcı olarak sil", en: "Permanently delete my account"))
                            .font(AppDesign.Typography.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppDesign.Colors.error)
            .disabled(isDeleting)
            Button(appViewModel.localized("common_cancel")) { dismiss() }
                .frame(maxWidth: .infinity)
                .disabled(isDeleting)
        }
        .padding(AppDesign.Spacing.xxl)
        .interactiveDismissDisabled(isDeleting)
        .alert(
            appViewModel.social("delete_account_confirm_title", tr: "Emin misin?", en: "Are you sure?"),
            isPresented: $confirming
        ) {
            Button(appViewModel.social("delete_account_confirm_button", tr: "Sil", en: "Delete"), role: .destructive) {
                Task { await delete() }
            }
            Button(appViewModel.localized("common_cancel"), role: .cancel) {}
        } message: {
            Text(appViewModel.social("delete_account_confirm_message",
                                     tr: "Bu işlem geri alınamaz.",
                                     en: "This cannot be undone."))
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
            Text("•")
            Text(text)
        }
    }

    private func delete() async {
        isDeleting = true
        errorMessage = nil
        do {
            try await appViewModel.deleteAccount()
            dismiss()
        } catch {
            errorMessage = error.message
        }
        isDeleting = false
    }
}
