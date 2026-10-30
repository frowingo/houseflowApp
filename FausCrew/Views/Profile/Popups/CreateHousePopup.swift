import SwiftUI
import FausCrewCore

/// Profile → House information → "Create a house". Same shell as `JoinHousePopup`:
/// brand header, scrolling form, Cancel / Create footer. Create stays disabled until
/// name, type and member count are all chosen (`HouseCreationRules.isValid`).
struct CreateHousePopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onDismiss: () -> Void

    @State private var houseName = ""
    @State private var houseType: HouseTypeCard.HouseType?
    @State private var memberCount: Int?
    @State private var isCreating = false
    @State private var errorMessage: String?
    @FocusState private var nameFocused: Bool
    @AccessibilityFocusState private var headerAccessibilityFocused: Bool

    private let range = HouseCreationRules.memberCountRange

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                AppDesign.Colors.scrim
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard !isCreating else { return }
                        requestDismiss()
                    }

                popupContent
                    .frame(maxWidth: 480)
                    .frame(
                        height: max(
                            0,
                            min(
                                proxy.size.height - 40,
                                dynamicTypeSize.isAccessibilitySize ? 620 : 520
                            )
                        )
                    )
                    .padding(.horizontal, AppDesign.Spacing.lg)
            }
        }
        .task {
            headerAccessibilityFocused = true
        }
    }

    private var popupContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
                    nameSection
                    typeSection
                    memberCountSection

                    if let errorMessage {
                        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.error)
                        .padding(AppDesign.Spacing.md)
                        .background(AppDesign.Colors.error.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    }
                }
                .padding(AppDesign.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .background(MainScreenBackground(surface: .popup))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .shadow(color: AppDesign.Colors.shadow.opacity(0.25), radius: 30, x: 0, y: 16)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            BrandPopupHeaderBackground()

            FausHouseIcon(size: 54, fill: .color(Color.white.opacity(0.13)))
                .offset(x: 85)

            HStack(spacing: AppDesign.Spacing.sm) {
                FausHouseIcon(size: 17, fill: .color(.white))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(appViewModel.localized("profile_house_create_title", fallback: "Create a house"))
                        .font(AppDesign.Typography.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .accessibilityFocused($headerAccessibilityFocused)

                    Text(appViewModel.localized(
                        "profile_house_create_subtitle",
                        fallback: "Set up a new home for your crew"
                    ))
                    .font(AppDesign.Typography.caption2)
                    .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                Button(action: requestDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isCreating)
                .accessibilityLabel(appViewModel.localized("common_close", fallback: "Close"))
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 64)
        .zIndex(1)
    }

    // MARK: - Form

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(appViewModel.localized("create_house_name_label", fallback: "House name"))

            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: "pencil")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(nameFocused ? FausBrand.orange : AppDesign.Colors.textSecondary)

                TextField(
                    appViewModel.localized("create_house_name_placeholder", fallback: "Enter a house name"),
                    text: $houseName
                )
                .font(AppDesign.Typography.body)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameFocused)
                .disabled(isCreating)
                .onChange(of: houseName) { _, newValue in
                    if newValue.count > HouseCreationRules.nameMaxLength {
                        houseName = String(newValue.prefix(HouseCreationRules.nameMaxLength))
                    }
                    errorMessage = nil
                }

                Text("\(houseName.count)/\(HouseCreationRules.nameMaxLength)")
                    .font(AppDesign.Typography.caption2)
                    .monospacedDigit()
                    .foregroundStyle(AppDesign.Colors.textSecondary)
            }
            .padding(.horizontal, AppDesign.Spacing.md)
            .frame(minHeight: 48)
            .background(AppDesign.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(
                        nameFocused ? FausBrand.orange : Color(red: 0.93, green: 0.91, blue: 0.89),
                        lineWidth: nameFocused ? 1.5 : 1
                    )
            )
        }
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(appViewModel.localized("create_house_type_label", fallback: "House type"))

            HStack(spacing: AppDesign.Spacing.sm) {
                ForEach(HouseTypeCard.HouseType.allCases, id: \.self) { type in
                    typeOption(type)
                }
            }
        }
    }

    private func typeOption(_ type: HouseTypeCard.HouseType) -> some View {
        let isSelected = houseType == type
        return Button {
            withAnimation(AppDesign.Animation.quick) {
                houseType = type
                errorMessage = nil
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? AnyShapeStyle(FausBrand.iconGradient) : AnyShapeStyle(Color(red: 0.96, green: 0.94, blue: 0.93)))
                        .frame(width: 34, height: 34)
                    typeIcon(type, color: isSelected ? .white : AppDesign.Colors.textSecondary)
                }

                Text(appViewModel.localized(type.localizationKey))
                    .font(AppDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? FausBrand.deepBerry : AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(isSelected ? FausBrand.orange.opacity(0.07) : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(
                        isSelected ? FausBrand.orange : Color(red: 0.93, green: 0.91, blue: 0.89),
                        lineWidth: 1.5
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func typeIcon(_ type: HouseTypeCard.HouseType, color: Color) -> some View {
        if type == .sharedHouse {
            FausHouseIcon(size: 18, fill: .color(color))
        } else {
            Image(systemName: type.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private var memberCountSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(appViewModel.localized("create_house_member_count_label", fallback: "Number of members"))

            HStack {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(FausBrand.orange)
                    Text(appViewModel.localized("profile_house_create_member_hint", fallback: "Up to"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                stepperButton(icon: "minus", isEnabled: canDecrease) {
                    if let memberCount { self.memberCount = memberCount - 1 }
                }

                Text(memberCount.map(String.init) ?? "–")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(memberCount == nil ? AppDesign.Colors.textSecondary : FausBrand.deepBerry)
                    .frame(minWidth: 28)
                    .contentTransition(.numericText())

                stepperButton(icon: "plus", isEnabled: canIncrease) {
                    memberCount = memberCount.map { $0 + 1 } ?? range.lowerBound
                }
            }
            .padding(.horizontal, AppDesign.Spacing.md)
            .padding(.vertical, AppDesign.Spacing.sm)
            .background(AppDesign.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(Color(red: 0.93, green: 0.91, blue: 0.89), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityValue(memberCount.map(String.init) ?? "–")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment where canIncrease:
                    memberCount = memberCount.map { $0 + 1 } ?? range.lowerBound
                case .decrement where canDecrease:
                    if let memberCount { self.memberCount = memberCount - 1 }
                default:
                    break
                }
            }
        }
    }

    private var canIncrease: Bool {
        !isCreating && (memberCount ?? 0) < range.upperBound
    }

    private var canDecrease: Bool {
        guard !isCreating, let memberCount else { return false }
        return memberCount > range.lowerBound
    }

    private func stepperButton(icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(AppDesign.Animation.quick) {
                action()
                errorMessage = nil
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isEnabled ? Color.white : AppDesign.Colors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(
                        isEnabled
                            ? AnyShapeStyle(FausBrand.buttonGradient)
                            : AnyShapeStyle(Color(red: 0.96, green: 0.94, blue: 0.93))
                    )
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AppDesign.Typography.subheadline.weight(.semibold))
            .foregroundStyle(AppDesign.Colors.textPrimary)
    }

    // MARK: - Footer

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AppDesign.Spacing.sm) {
                    createButton
                    cancelButton
                }
            } else {
                HStack(spacing: AppDesign.Spacing.md) {
                    cancelButton
                    createButton
                }
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(AppDesign.Colors.background)
        .overlay(alignment: .top) {
            Divider().overlay(AppDesign.Colors.separator)
        }
    }

    private var cancelButton: some View {
        Button(action: requestDismiss) {
            Text(appViewModel.localized("common_cancel", fallback: "Cancel"))
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(AppDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isCreating)
    }

    private var createButton: some View {
        Button(action: submit) {
            HStack(spacing: AppDesign.Spacing.sm) {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "plus.circle.fill")
                }
                Text(appViewModel.localized(
                    isCreating ? "common_creating" : "profile_house_create_button",
                    fallback: isCreating ? "Creating…" : "Create house"
                ))
                .fixedSize(horizontal: false, vertical: true)
            }
            .font(AppDesign.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
            .padding(.vertical, AppDesign.Spacing.xs)
            .background(createButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(!canCreate)
    }

    private var isFormValid: Bool {
        HouseCreationRules.isValid(name: houseName, type: houseType?.apiValue, memberCount: memberCount)
    }

    private var canCreate: Bool {
        isFormValid && !isCreating
    }

    private var createButtonBackground: some View {
        Group {
            if canCreate || isCreating {
                FausBrand.buttonGradient
            } else {
                LinearGradient(
                    colors: [AppDesign.Colors.textTertiary.opacity(0.42), AppDesign.Colors.textTertiary.opacity(0.32)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    // MARK: - Actions

    private func submit() {
        guard canCreate, let houseType, let memberCount else { return }
        nameFocused = false
        Task { await createHouse(type: houseType.apiValue, memberCount: memberCount) }
    }

    @MainActor
    private func createHouse(type: Int, memberCount: Int) async {
        isCreating = true
        errorMessage = nil
        do {
            _ = try await appViewModel.createHouseFromProfile(
                name: houseName,
                type: type,
                maxMemberCount: memberCount
            )
            isCreating = false
            appViewModel.showToast(
                message: appViewModel.localized(
                    "profile_house_create_success",
                    fallback: "House created."
                ),
                isError: false
            )
            requestDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }

    private func requestDismiss() {
        guard !isCreating else { return }
        nameFocused = false
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
