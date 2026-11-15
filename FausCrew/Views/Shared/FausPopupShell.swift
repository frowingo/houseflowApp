import SwiftUI

/// Card chrome shared by the Profile popups: brand header (watermark, optional badge, title,
/// subtitle, close button), body and footer on the popup surface. The caller owns the scrim and
/// the card's size, because those differ between popups.
struct FausPopupShell<Watermark: View, Badge: View, Content: View, Footer: View>: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @AccessibilityFocusState private var isTitleFocused: Bool

    let watermark: Watermark
    let watermarkOffset: CGFloat
    let title: String
    let subtitle: String
    let isCloseDisabled: Bool
    let onClose: () -> Void
    let badge: Badge?
    let content: Content
    let footer: Footer

    init(
        watermark: Watermark,
        watermarkOffset: CGFloat = 0,
        title: String,
        subtitle: String,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void,
        badge: Badge?,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.watermark = watermark
        self.watermarkOffset = watermarkOffset
        self.title = title
        self.subtitle = subtitle
        self.isCloseDisabled = isCloseDisabled
        self.onClose = onClose
        self.badge = badge
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
            footer
        }
        .background(MainScreenBackground(surface: .popup))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .shadow(color: AppDesign.Colors.shadow.opacity(0.25), radius: 30, x: 0, y: 16)
        .accessibilityAddTraits(.isModal)
        .task { isTitleFocused = true }
    }

    private var header: some View {
        ZStack {
            BrandPopupHeaderBackground()

            watermark
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(AppDesign.Colors.onHero.opacity(0.12))
                .offset(x: watermarkOffset)

            HStack(spacing: AppDesign.Spacing.sm) {
                if let badge {
                    badge
                        .foregroundStyle(AppDesign.Colors.onHero)
                        .frame(width: 34, height: 34)
                        .background(AppDesign.Colors.onHero.opacity(0.18))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppDesign.Colors.onHero)
                        .lineLimit(1)
                        .accessibilityFocused($isTitleFocused)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppDesign.Colors.onHero.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppDesign.Colors.onHero.opacity(0.9))
                        .frame(width: 28, height: 28)
                        .background(AppDesign.Colors.onHero.opacity(0.2))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCloseDisabled)
                .accessibilityLabel(appViewModel.localized("common_close", fallback: "Close"))
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 64)
        .zIndex(1)
    }
}

extension FausPopupShell where Badge == EmptyView {
    init(
        watermark: Watermark,
        watermarkOffset: CGFloat = 0,
        title: String,
        subtitle: String,
        isCloseDisabled: Bool = false,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            watermark: watermark,
            watermarkOffset: watermarkOffset,
            title: title,
            subtitle: subtitle,
            isCloseDisabled: isCloseDisabled,
            onClose: onClose,
            badge: nil,
            content: content,
            footer: footer
        )
    }
}
