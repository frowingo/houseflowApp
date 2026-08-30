import SwiftUI

// MARK: - Language Settings Popup

struct LanguageSettingsPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var selectedPrefix: String?
    @State private var isSaving = false
    @State private var saveError: String?

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { requestDismiss() } }

            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("language_settings_title"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.localized("language_settings_subtitle"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Spacer()

                        Button { if !isSaving { requestDismiss() } } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 64)

                ScrollView(showsIndicators: false) {
                    if appViewModel.isLoadingLocalizationLanguages && appViewModel.localizationLanguages.isEmpty {
                        ProgressView()
                            .tint(accentOrange)
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, minHeight: 190)
                    } else if appViewModel.localizationLanguages.isEmpty {
                        VStack(spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "globe.badge.chevron.backward")
                                .font(.system(size: 36))
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                            Text(appViewModel.localized("language_settings_empty_message"))
                                .font(AppDesign.Typography.subheadline)
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 190)
                    } else {
                        LazyVGrid(columns: columns, spacing: AppDesign.Spacing.md) {
                            ForEach(appViewModel.localizationLanguages) { language in
                                languageCell(language)
                            }
                        }
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .padding(.vertical, AppDesign.Spacing.xl)
                    }
                }
                .frame(maxHeight: 360)

                if let error = saveError {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .font(AppDesign.Typography.caption)
                        Spacer()
                    }
                    .foregroundStyle(AppDesign.Colors.error)
                    .padding(AppDesign.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .fill(AppDesign.Colors.error.opacity(0.1))
                    )
                    .padding(.horizontal, AppDesign.Spacing.xl)
                }

                VStack(spacing: AppDesign.Spacing.sm) {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            if isSaving {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(appViewModel.localized(isSaving ? "common_saving" : "common_save_changes"))
                                .font(AppDesign.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            canSave
                                ? LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(!canSave)

                    Button { if !isSaving { requestDismiss() } } label: {
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
                .background(AppDesign.Colors.background.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4))
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: isSaving)
        .animation(AppDesign.Animation.spring, value: selectedPrefix)
        .task { await loadLanguages() }
        .onAppear {
            selectedPrefix = normalized(appViewModel.currentLanguagePrefix)
        }
    }

    @ViewBuilder
    private func languageCell(_ language: LocalizationLanguage) -> some View {
        let isSelected = selectedPrefix == normalized(language.prefix)

        Button {
            guard language.isActive, !isSaving else { return }
            withAnimation(AppDesign.Animation.spring) {
                selectedPrefix = normalized(language.prefix)
            }
        } label: {
            VStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    CachedRemoteImage(url: URL(string: language.image)) { remoteImage in
                        remoteImage.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            AppDesign.Colors.secondaryBackground
                            ProgressView().tint(accentOrange)
                        }
                    } failure: {
                        ZStack {
                            AppDesign.Colors.secondaryBackground
                            Image(systemName: "globe")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                    }
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .opacity(language.isActive ? 1 : 0.38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? accentOrange : Color.clear, lineWidth: 3)
                    )
                    .scaleEffect(isSelected ? 1.04 : 1.0)

                    if !language.isActive {
                        Text(appViewModel.localized("language_settings_coming_soon_badge"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.58)))
                    }

                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(accentOrange)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Spacer()
                        }
                        .frame(width: 86, height: 86)
                        .offset(x: 7, y: -7)
                    }
                }

                Text(language.nativeName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(language.isActive ? AppDesign.Colors.textPrimary : AppDesign.Colors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppDesign.Spacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(!language.isActive || isSaving)
        .shadow(
            color: (isSelected ? accentOrange : Color.black).opacity(isSelected ? 0.32 : 0.08),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: 3
        )
    }

    private var canSave: Bool {
        guard !isSaving else { return false }
        guard let selected = selectedPrefix, !selected.isEmpty else { return false }
        guard selected != normalized(appViewModel.currentLanguagePrefix) else { return false }
        return appViewModel.localizationLanguages.first { normalized($0.prefix) == selected }?.isActive == true
    }

    private func loadLanguages() async {
        saveError = nil
        do {
            try await appViewModel.loadLocalizationLanguages()
            await MainActor.run {
                if selectedPrefix == nil {
                    selectedPrefix = normalized(appViewModel.currentLanguagePrefix)
                }
                if selectedPrefix == nil {
                    selectedPrefix = appViewModel.localizationLanguages.first(where: { $0.isDefault })?.prefix
                }
            }
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func save() async {
        guard canSave, let selectedPrefix else { return }
        isSaving = true
        saveError = nil
        do {
            try await appViewModel.saveLanguagePreferenceAndRequireLogin(prefix: selectedPrefix)
            isSaving = false
            requestDismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }

    private func normalized(_ prefix: String?) -> String? {
        guard let prefix else { return nil }
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedPrefix.isEmpty ? nil : normalizedPrefix
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
