import SwiftUI

/// Announcement composer UI. The publish closure returns whether the server
/// accepted the announcement so the form stays open when a request fails.
struct NewAnnouncementPopup: View {
    let appViewModel: AppViewModel
    let onPublish: (_ title: String, _ message: String) async -> Bool
    let onDismiss: () -> Void

    private enum Field: Hashable {
        case title
        case message
    }

    @State private var title = ""
    @State private var message = ""
    @State private var isPublishing = false
    @FocusState private var focusedField: Field?

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)
    private let titleLimit = 30
    private let messageLimit = 150

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canPublish: Bool {
        !trimmedTitle.isEmpty && !trimmedMessage.isEmpty && !isPublishing
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isPublishing { requestDismiss() }
                }

            VStack(spacing: 0) {
                topBar
                    .zIndex(1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        intro
                        titleField
                        messageField
                    }
                    .padding(AppDesign.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: 430)
                .clipped()

                actionButtons
            }
            .background(MainScreenBackground())
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl)
                    .strokeBorder(accentOrange.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.24), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
    }

    private var topBar: some View {
        ZStack {
            BrandPopupHeaderBackground(topCornerRadius: AppDesign.CornerRadius.xxl)

            Image(systemName: "megaphone.fill")
                .font(.system(size: 60, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.10))
                .offset(x: 84)

            HStack(spacing: AppDesign.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 34, height: 34)
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Text(appViewModel.localized(
                    "new_announcement_title",
                    fallback: "New announcement"
                ))
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: requestDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isPublishing)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 62)
    }

    private var intro: some View {
        Text(appViewModel.localized(
            "new_announcement_subtitle",
            fallback: "Share an important update with everyone in your house."
        ))
            .font(AppDesign.Typography.subheadline)
            .foregroundStyle(AppDesign.Colors.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var titleField: some View {
        formField(
            icon: "textformat",
            label: appViewModel.localized(
                "new_announcement_title_label",
                fallback: "Title"
            ),
            count: title.count,
            limit: titleLimit
        ) {
            TextField(
                appViewModel.localized(
                    "new_announcement_title_placeholder",
                    fallback: "What should everyone know?"
                ),
                text: $title
            )
            .font(AppDesign.Typography.body)
            .focused($focusedField, equals: .title)
            .submitLabel(.next)
            .onSubmit { focusedField = .message }
            .onChange(of: title) { _, newValue in
                title = String(newValue.prefix(titleLimit))
            }
            .padding(AppDesign.Spacing.md)
            .background(fieldBackground(isActive: focusedField == .title))
        }
    }

    private var messageField: some View {
        formField(
            icon: "text.alignleft",
            label: appViewModel.localized(
                "new_announcement_message_label",
                fallback: "Message"
            ),
            count: message.count,
            limit: messageLimit
        ) {
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text(appViewModel.localized(
                        "new_announcement_message_placeholder",
                        fallback: "Write the announcement details..."
                    ))
                        .font(AppDesign.Typography.body)
                        .foregroundStyle(AppDesign.Colors.textTertiary)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 19)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $message)
                    .font(AppDesign.Typography.body)
                    .focused($focusedField, equals: .message)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 116)
                    .padding(AppDesign.Spacing.sm)
                    .onChange(of: message) { _, newValue in
                        message = String(newValue.prefix(messageLimit))
                    }
            }
            .background(fieldBackground(isActive: focusedField == .message))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Button {
                Task { await publish() }
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    if isPublishing {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(.white)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    Text(appViewModel.localized(
                        isPublishing ? "common_publishing" : "new_announcement_publish_button",
                        fallback: isPublishing ? "Publishing..." : "Publish announcement"
                    ))
                        .font(AppDesign.Typography.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: canPublish
                            ? [accentOrange, Color(red: 0.90, green: 0.34, blue: 0.08)]
                            : [Color(.systemGray3), Color(.systemGray4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                .shadow(color: canPublish ? accentOrange.opacity(0.28) : .clear, radius: 9, x: 0, y: 4)
            }
            .disabled(!canPublish)

            Button(action: requestDismiss) {
                Text(appViewModel.localized("common_cancel"))
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .disabled(isPublishing)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.top, AppDesign.Spacing.md)
        .padding(.bottom, AppDesign.Spacing.xl)
        .background(AppDesign.Colors.background)
    }

    private func formField<Content: View>(
        icon: String,
        label: String,
        count: Int,
        limit: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(accentOrange)
                Text(label)
                    .font(AppDesign.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                Spacer()
                Text("\(count)/\(limit)")
                    .font(AppDesign.Typography.caption2)
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .monospacedDigit()
            }

            content()
        }
    }

    private func fieldBackground(isActive: Bool) -> some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .fill(AppDesign.Colors.secondaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(isActive ? accentOrange.opacity(0.60) : Color.clear, lineWidth: 1.5)
            )
    }

    @MainActor
    private func publish() async {
        guard canPublish else { return }
        focusedField = nil
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isPublishing = true
        let didPublish = await onPublish(trimmedTitle, trimmedMessage)
        isPublishing = false
        if didPublish { requestDismiss() }
    }

    private func requestDismiss() {
        focusedField = nil
        onDismiss()
    }
}

#Preview {
    NewAnnouncementPopup(
        appViewModel: AppViewModel(),
        onPublish: { _, _ in true },
        onDismiss: {}
    )
}
