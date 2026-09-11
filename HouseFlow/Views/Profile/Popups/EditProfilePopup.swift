import SwiftUI

// MARK: - Edit Profile Popup

struct EditProfilePopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onDismiss: () -> Void

    private enum EditField: Hashable {
        case firstName
        case lastName
    }

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var initialFirstName: String = ""
    @State private var initialLastName: String = ""
    @State private var initialBirthDate: Date?
    @State private var maximumBirthDate = Date()
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focusedField: EditField?

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { requestDismiss() } }

            VStack(spacing: 0) {
                // ── Top bar (ChoreDetailPopup style)
                ZStack {
                    BrandPopupHeaderBackground()
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 34, height: 34)
                            Text(previewInitials)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("profile_edit_button"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.currentUserProfile?.email ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.72))
                                .lineLimit(1)
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
                .frame(height: 60)
                .zIndex(1)

                // ── Scrollable fields
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.md) {
                        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accentOrange)

                            Text(
                                appViewModel.localized(
                                    "profile_edit_twenty_day_warning",
                                    fallback: "You can update your first name, last name, and birthdate once every 20 days."
                                )
                            )
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(AppDesign.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(AppDesign.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .fill(accentOrange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                        .stroke(accentOrange.opacity(0.25), lineWidth: 1)
                                )
                        )

                        fieldSection(icon: "person.fill", tint: accentOrange, title: appViewModel.localized("profile_edit_name_section")) {
                            editField(icon: "person.fill", tint: accentOrange,
                                      placeholder: appViewModel.localized("profile_first_name_label"), text: $firstName, field: .firstName)
                            Divider().padding(.leading, 66)
                            editField(icon: "person.fill", tint: accentOrange,
                                      placeholder: appViewModel.localized("profile_last_name_label"),  text: $lastName, field: .lastName)
                        }

                        fieldSection(icon: "info.circle.fill",
                                     tint: Color(red: 0.2, green: 0.7, blue: 0.4),
                                     title: appViewModel.localized("profile_edit_details_section")) {
                            HStack(spacing: AppDesign.Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.9, green: 0.45, blue: 0.1).opacity(0.13))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "birthday.cake.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(red: 0.9, green: 0.45, blue: 0.1))
                                }
                                Text(appViewModel.localized("profile_birthdate_label"))
                                    .font(AppDesign.Typography.subheadline)
                                    .foregroundStyle(AppDesign.Colors.textSecondary)
                                Spacer()
                                DatePicker("", selection: $birthDate, in: ...maximumBirthDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Color(red: 0.9, green: 0.45, blue: 0.1))
                            }
                            .padding(.horizontal, AppDesign.Spacing.lg)
                            .padding(.vertical, 14)
                        }

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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                            .stroke(AppDesign.Colors.error.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: 420)
                .clipped()

                // ── Footer: Save + Cancel
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
                            isSaving || !hasChanges
                                ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(isSaving || !hasChanges)
                    .animation(AppDesign.Animation.quick, value: hasChanges)
                    .animation(AppDesign.Animation.quick, value: isSaving)

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
                .background(
                    AppDesign.Colors.background
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
                )
            }
            .background(MainScreenBackground())
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: isSaving)
        .onAppear(perform: populate)
    }

    // MARK: - Field Section

    @ViewBuilder
    private func fieldSection<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(tint.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .kerning(0.9)
                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.md)
            .padding(.bottom, AppDesign.Spacing.sm)

            Divider().padding(.horizontal, AppDesign.Spacing.lg)

            content()
        }
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func editField(
        icon: String,
        tint: Color,
        placeholder: String,
        text: Binding<String>,
        field: EditField,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
            }
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(AppDesign.Typography.subheadline)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var normalizedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasFirstNameChanged: Bool {
        normalizedFirstName != initialFirstName
    }

    private var hasLastNameChanged: Bool {
        normalizedLastName != initialLastName
    }

    private var hasBirthDateChanged: Bool {
        guard let initialBirthDate else { return false }
        return !Calendar.current.isDate(birthDate, inSameDayAs: initialBirthDate)
    }

    private var hasChanges: Bool {
        hasFirstNameChanged || hasLastNameChanged || hasBirthDateChanged
    }

    private var previewInitials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        if f.isEmpty && l.isEmpty {
            return appViewModel.currentUserProfile.map {
                "\($0.firstName.prefix(1))\($0.lastName.prefix(1))"
            }?.uppercased() ?? "?"
        }
        return "\(f)\(l)".uppercased()
    }

    private func populate() {
        guard let p = appViewModel.currentUserProfile else { return }
        firstName   = p.firstName
        lastName    = p.lastName
        initialFirstName = p.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        initialLastName = p.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bd = p.birthDate, !bd.isEmpty {
            if let parsed = HouseFlowDateFormatter.parseAPIDate(bd) {
                birthDate = parsed
                initialBirthDate = parsed
                return
            }
        }
        initialBirthDate = birthDate
    }

    private func requestDismiss() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            onDismiss()
        }
    }

    // MARK: - Save (PUT user/profile)

    @MainActor
    private func save() async {
        guard !isSaving, hasChanges else { return }
        isSaving  = true
        saveError = nil
        let request = UpdateProfileRequest(
            imageUrl:      nil,
            birthDay:      hasBirthDateChanged ? HouseFlowDateFormatter.apiString(from: birthDate) : nil,
            firstName:     hasFirstNameChanged ? normalizedFirstName : nil,
            lastName:      hasLastNameChanged ? normalizedLastName : nil,
            phoneNumber:   nil
        )
        do {
            try await appViewModel.updateProfile(request)
            isSaving = false
            requestDismiss()
        } catch {
            isSaving  = false
            saveError = error.localizedDescription
        }
    }
}
