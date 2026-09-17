import SwiftUI
import UIKit

struct HouseInviteCodeSection: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let houseId: String
    let houseName: String

    @State private var invite: HouseInviteCodeData?
    @State private var isGenerating = false
    @State private var didCopy = false
    @State private var errorMessage: String?

    private let tint = Color(red: 0.12, green: 0.55, blue: 0.54)

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Label(
                appViewModel.localized(
                    "house_info_invite_title",
                    fallback: "Invite housemates"
                ),
                systemImage: "person.badge.plus"
            )
            .font(AppDesign.Typography.subheadline.weight(.bold))
            .foregroundStyle(AppDesign.Colors.textPrimary)

            if let invite {
                generatedCode(invite)
            } else {
                generateButton
            }

            if let errorMessage {
                HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(errorMessage)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .font(AppDesign.Typography.caption)
                .foregroundStyle(AppDesign.Colors.error)
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(tint.opacity(0.075))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                .strokeBorder(tint.opacity(0.16), lineWidth: 1)
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generateCode() }
        } label: {
            HStack(spacing: AppDesign.Spacing.sm) {
                if isGenerating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "key.fill")
                }

                Text(
                    appViewModel.localized(
                        isGenerating
                            ? "house_info_invite_generating"
                            : "house_info_invite_generate_button",
                        fallback: isGenerating ? "Creating code…" : "Create invite code"
                    )
                )
            }
            .font(AppDesign.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
            .padding(.vertical, AppDesign.Spacing.xs)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    private func generatedCode(_ invite: HouseInviteCodeData) -> some View {
        VStack(spacing: AppDesign.Spacing.md) {
            HStack(spacing: AppDesign.Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(invite.inviteCode)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                        .tracking(2)
                        .textSelection(.enabled)

                    Text(expirationText(invite.expiresInSeconds))
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                }

                Spacer(minLength: 0)

                Button(action: copyCode) {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(didCopy ? AppDesign.Colors.success : tint)
                        .frame(width: 36, height: 36)
                        .background((didCopy ? AppDesign.Colors.success : tint).opacity(0.11))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    appViewModel.localized("common_copy", fallback: "Copy")
                )
                .accessibilityValue(
                    didCopy
                        ? appViewModel.localized("invite_popup_copied", fallback: "Copied")
                        : ""
                )
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: AppDesign.Spacing.sm) {
                        refreshButton
                        shareButton(invite.inviteCode)
                    }
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        refreshButton
                        shareButton(invite.inviteCode)
                    }
                }
            }
            .font(AppDesign.Typography.subheadline.weight(.semibold))
            .foregroundStyle(AppDesign.Colors.textPrimary)
        }
    }

    private var refreshButton: some View {
        Button {
            Task { await generateCode() }
        } label: {
            Label(
                appViewModel.localized(
                    "house_info_invite_refresh_button",
                    fallback: "New code"
                ),
                systemImage: "arrow.clockwise"
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
            .padding(.vertical, AppDesign.Spacing.xs)
            .background(AppDesign.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    private func shareButton(_ inviteCode: String) -> some View {
        ShareLink(item: shareMessage(inviteCode)) {
            Label(
                appViewModel.localized("common_share", fallback: "Share"),
                systemImage: "square.and.arrow.up"
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
            .padding(.vertical, AppDesign.Spacing.xs)
            .foregroundStyle(.white)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .disabled(isGenerating)
    }

    @MainActor
    private func generateCode() async {
        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        do {
            invite = try await appViewModel.createHouseInviteCode(houseId: houseId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isGenerating = false
    }

    private func copyCode() {
        guard let invite else { return }
        UIPasteboard.general.string = invite.inviteCode
        withAnimation(AppDesign.Animation.quick) {
            didCopy = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(AppDesign.Animation.quick) {
                didCopy = false
            }
        }
    }

    private func expirationText(_ seconds: Int) -> String {
        let duration: String
        if seconds >= 3_600 {
            duration = "\(seconds / 3_600)h \((seconds % 3_600) / 60)m"
        } else if seconds >= 60 {
            duration = "\(seconds / 60)m"
        } else {
            duration = "\(max(0, seconds))s"
        }

        let template = appViewModel.localized(
            "house_info_invite_expiration_template",
            fallback: "Expires in {duration}"
        )
        return template.replacingOccurrences(of: "{duration}", with: duration)
    }

    private func shareMessage(_ inviteCode: String) -> String {
        let template = appViewModel.localized(
            "invite_share_message_template",
            fallback: "Join {house_name} on HouseFlow with invite code {invite_code}."
        )
        return template
            .replacingOccurrences(of: "{house_name}", with: houseName)
            .replacingOccurrences(of: "{invite_code}", with: inviteCode)
    }
}
