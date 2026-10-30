import FausCrewCore
import SwiftUI

// MARK: - Theme Settings Popup

/// Theme picker opened from Profile › Settings › Theme. Each option previews itself with its
/// own palette; Save applies the theme at once and stores it on the device.
struct ThemeSettingsPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var themeStore: ThemeStore
    let onDismiss: () -> Void

    @State private var selectedID: AppThemeID?

    private var currentID: AppThemeID { themeStore.themeID }
    private var canSave: Bool { (selectedID ?? currentID) != currentID }

    var body: some View {
        ZStack {
            AppDesign.Colors.scrim
                .ignoresSafeArea()
                .onTapGesture { requestDismiss() }

            VStack(spacing: 0) {
                ZStack {
                    BrandPopupHeaderBackground()
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundColor(AppDesign.Colors.onHero.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("theme_settings_title", fallback: "Theme"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppDesign.Colors.onHero)
                            Text(appViewModel.localized("theme_settings_subtitle", fallback: "Choose how FausCrew looks"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppDesign.Colors.onHero.opacity(0.75))
                        }

                        Spacer()

                        Button { requestDismiss() } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppDesign.Colors.onHero.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(AppDesign.Colors.onHero.opacity(0.2))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(appViewModel.localized("common_close"))
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 64)
                .zIndex(1)

                VStack(spacing: AppDesign.Spacing.md) {
                    ForEach(FausTheme.all) { theme in
                        themeOption(theme)
                    }
                }
                .padding(AppDesign.Spacing.xl)

                VStack(spacing: AppDesign.Spacing.sm) {
                    Button(action: save) {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text(appViewModel.localized("common_save_changes"))
                                .font(AppDesign.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            canSave
                                ? LinearGradient(colors: [HouseJourneyTheme.accentOrange, HouseJourneyTheme.accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [AppDesign.Colors.controlFillStrong, AppDesign.Colors.controlFill], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(!canSave)

                    Button { requestDismiss() } label: {
                        Text(appViewModel.localized("common_cancel"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeightSmall)
                            .background(AppDesign.Colors.secondaryBackground)
                            .cornerRadius(AppDesign.CornerRadius.md)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(AppDesign.Colors.popupBackground.shadow(color: AppDesign.Colors.shadow.opacity(0.06), radius: 8, x: 0, y: -4))
            }
            .background(MainScreenBackground(surface: .popup))
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
            .shadow(color: AppDesign.Colors.shadow.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.spring, value: selectedID)
        .onAppear { selectedID = currentID }
    }

    private func themeOption(_ theme: FausTheme) -> some View {
        let isSelected = (selectedID ?? currentID) == theme.id
        return Button {
            selectedID = theme.id
        } label: {
            HStack(spacing: AppDesign.Spacing.md) {
                ThemePreviewThumbnail(theme: theme)

                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: theme.displayName)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                    Text(appViewModel.localized(theme.descriptionKey, fallback: theme.descriptionFallback))
                        .font(.system(size: 12))
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? HouseJourneyTheme.accentOrange : AppDesign.Colors.controlFill, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(HouseJourneyTheme.accentOrange)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(AppDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                    .fill(AppDesign.Colors.menuBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                    .strokeBorder(isSelected ? HouseJourneyTheme.accentOrange : AppDesign.Colors.hairline, lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func save() {
        guard let selectedID, canSave else { return }
        themeStore.select(selectedID)
        requestDismiss()
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}

// MARK: - Preview Thumbnail

/// A miniature main screen painted with the theme's own tokens: backdrop, hero card, two cards
/// and the floating tab bar. It renders in the theme's color scheme so system colors resolve
/// the way they will in the app.
struct ThemePreviewThumbnail: View {
    let theme: FausTheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        ZStack(alignment: .top) {
            LinearGradient(stops: backdropStops, startPoint: .top, endPoint: .bottom)

            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(stops: theme.decor.heroStops, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(FausHeroGlow(color: theme.decor.heroGlow).clipShape(RoundedRectangle(cornerRadius: 5)))
                    .frame(height: 20)

                ForEach(0..<2, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(uiColor: theme.palette.cardBackground))
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 3) {
                                Capsule().fill(Color(uiColor: theme.palette.textPrimary).opacity(0.7)).frame(width: 22, height: 3)
                                Capsule().fill(Color(uiColor: theme.palette.textTertiary).opacity(0.6)).frame(width: index == 0 ? 30 : 18, height: 3)
                            }
                            .padding(.leading, 5)
                        }
                        .frame(height: 17)
                }

                Spacer(minLength: 0)

                Capsule()
                    .fill(LinearGradient(stops: theme.decor.tabBarStops, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(alignment: .leading) {
                        Capsule().fill(theme.decor.tabSelectedFill).frame(width: 13, height: 7).padding(.leading, 5)
                    }
                    .frame(height: 11)
            }
            .padding(5)
        }
        .frame(width: 64, height: 88)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color(uiColor: theme.palette.hairline), lineWidth: 1))
        .environment(\.colorScheme, theme.colorScheme)
        .accessibilityHidden(true)
    }

    private var backdropStops: [Gradient.Stop] {
        let stops = theme.decor.backdrop.baseStops
        return stops.count > 1 ? stops : stops + stops.map { .init(color: $0.color, location: 1) }
    }
}
