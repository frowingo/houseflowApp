import SwiftUI

// MARK: - Avatar Picker Popup

struct AvatarPickerPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let initials: String
    let onDismiss: () -> Void

    @State private var images: [UserImageData] = []
    @State private var isLoading = false
    @State private var selectedImage: UserImageData? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { requestDismiss() } }

            VStack(spacing: 0) {
                // Top bar
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("profile_avatar_choose_title"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.localized("profile_avatar_choose_subtitle"))
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

                // Grid body
                ScrollView(showsIndicators: false) {
                    if isLoading {
                        ProgressView()
                            .tint(accentOrange)
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if images.isEmpty {
                        VStack(spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                            Text(appViewModel.localized("profile_avatar_empty_message"))
                                .font(AppDesign.Typography.subheadline)
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        LazyVGrid(columns: columns, spacing: AppDesign.Spacing.md) {
                            ForEach(images, id: \.publicId) { image in
                                imageCell(image: image)
                            }
                        }
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .padding(.vertical, AppDesign.Spacing.xl)
                    }
                }
                .frame(maxHeight: 340)

                // Error
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

                // Footer
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
                            selectedImage == nil || isSaving
                                ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(selectedImage == nil || isSaving)

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
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: isSaving)
        .task { await fetchImages() }
    }

    // MARK: - Image Cell

    @ViewBuilder
    private func imageCell(image: UserImageData) -> some View {
        let isSelected = selectedImage?.publicId == image.publicId
        Button {
            withAnimation(AppDesign.Animation.spring) {
                selectedImage = image
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                CachedRemoteImage(url: URL(string: image.fileURL)) { remoteImage in
                    remoteImage.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Color(AppDesign.Colors.secondaryBackground)
                        ProgressView().tint(accentOrange)
                    }
                } failure: {
                    ZStack {
                        Color(AppDesign.Colors.secondaryBackground)
                        Image(systemName: "photo")
                            .foregroundStyle(AppDesign.Colors.textTertiary)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isSelected ? accentOrange : Color.clear,
                            lineWidth: 3
                        )
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(accentOrange)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .shadow(
                color: (isSelected ? accentOrange : Color.black).opacity(isSelected ? 0.35 : 0.1),
                radius: isSelected ? 8 : 4,
                x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .animation(AppDesign.Animation.spring, value: isSelected)
    }

    // MARK: - Fetch

    private func fetchImages() async {
        isLoading = true
        saveError = nil
        do {
            let response = try await appViewModel.fetchProfileImages(category: "profile/superhero")
            await MainActor.run {
                images = response.data
                // Pre-select current imageUrl if it matches one of the fetched images
                if let currentUrl = appViewModel.currentUserProfile?.imageUrl,
                   let match = response.data.first(where: { $0.fileURL == currentUrl }) {
                    selectedImage = match
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Save

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        guard let image = selectedImage else { return }
        isSaving = true
        saveError = nil
        let request = UpdateProfileRequest(
            imageUrl: image.fileURL,
            birthDay: nil,
            firstName: nil,
            lastName: nil,
            phoneNumber: nil
        )
        do {
            try await appViewModel.updateProfile(request)
            isSaving = false
            requestDismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
