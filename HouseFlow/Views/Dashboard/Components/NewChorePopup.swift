import SwiftUI

private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

/// Premium new-chore creation sheet with API integration.
struct NewChorePopup: View {
    let appViewModel: AppViewModel
    let onDismiss: () -> Void

    private enum NewChoreField: Hashable {
        case title
        case description
        case interval
    }

    @State private var title = ""
    @State private var description = ""
    @State private var selectedMember: User? = nil
    @State private var selectedLevel: ChoreLevel = .easy
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var minimumDueDate = Date()
    @State private var isRecurring: Bool = false
    @State private var recurringInterval: Int = 7
    @State private var intervalText: String = "7"
    @State private var isCreating: Bool = false
    @FocusState private var focusedField: NewChoreField?

    private var members: [User] { appViewModel.dashboardMembers }
    private var houseId: String { appViewModel.currentHouseDetails?.id ?? "" }

    private var canCreate: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedMember?.apiId != nil
            && !houseId.isEmpty
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isCreating { requestDismiss() } }

            VStack(spacing: 0) {
                topBar
                    .zIndex(1)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        titleField
                        descriptionField
                        memberPicker
                        levelPicker
                        dueDatePicker
                        recurringSection
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: 460)
                .clipped()

                actionButtons
            }
            .background(MainScreenBackground())
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .dismissKeyboardOnTap()
        .onAppear { selectedMember = members.first }
        .animation(AppDesign.Animation.standard, value: isCreating)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            BrandPopupHeaderBackground()
            // Background decorative icon
            Image(systemName: "sparkles")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white.opacity(0.12))

            HStack(spacing: AppDesign.Spacing.md) {
                Text(appViewModel.localized("new_chore_title"))
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(.white)
                Spacer()
                Button { if !isCreating { requestDismiss() } } label: {
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
        .frame(height: 52)
    }

    // MARK: - Fields

    private var titleField: some View {
        formField(icon: "pencil", label: appViewModel.localized("new_chore_task_name_label")) {
            TextField(appViewModel.localized("new_chore_task_name_placeholder"), text: $title)
                .font(AppDesign.Typography.body)
                .focused($focusedField, equals: .title)
                .padding(AppDesign.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .fill(AppDesign.Colors.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .stroke(title.isEmpty ? Color.clear : accentOrange.opacity(0.5), lineWidth: 1.5)
                        )
                )
        }
    }

    private var descriptionField: some View {
        formField(icon: "text.alignleft", label: appViewModel.localized("new_chore_description_label")) {
            TextField(appViewModel.localized("new_chore_description_placeholder"), text: $description, axis: .vertical)
                .font(AppDesign.Typography.body)
                .lineLimit(2...4)
                .focused($focusedField, equals: .description)
                .padding(AppDesign.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .fill(AppDesign.Colors.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .stroke(description.isEmpty ? Color.clear : accentOrange.opacity(0.5), lineWidth: 1.5)
                        )
                )
        }
    }

    private var memberPicker: some View {
        formField(icon: "person.fill", label: appViewModel.localized("new_chore_assign_to_label")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppDesign.Spacing.md) {
                    ForEach(members) { member in
                        let isSel = selectedMember?.id == member.id
                        Button { withAnimation(AppDesign.Animation.quick) { selectedMember = member } } label: {
                            VStack(spacing: 6) {
                                ZStack(alignment: .topTrailing) {
                                    // Outer selection ring
                                    Circle()
                                        .stroke(isSel ? accentOrange : Color.clear, lineWidth: 3)
                                        .frame(width: 48, height: 48)
                                    UserAvatar(user: member, size: 40)
                                        .padding(4)
                                        .background(Circle().fill(isSel ? accentOrange.opacity(0.15) : Color.clear))
                                    // Checkmark badge
                                    if isSel {
                                        ZStack {
                                            Circle().fill(Color.white).frame(width: 18, height: 18)
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(accentOrange)
                                        }
                                        .offset(x: 4, y: -4)
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .frame(width: 52, height: 52)
                                Text(member.firstName)
                                    .font(.system(size: 11, weight: isSel ? .bold : .medium))
                                    .foregroundColor(isSel ? accentOrange : AppDesign.Colors.textSecondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                    .fill(isSel ? accentOrange.opacity(0.08) : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(AppDesign.Animation.quick, value: isSel)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var levelPicker: some View {
        formField(icon: "flame.fill", label: appViewModel.localized("new_chore_difficulty_label")) {
            HStack(spacing: AppDesign.Spacing.sm) {
                ForEach([ChoreLevel.easy, .medium, .hard], id: \.rawValue) { lvl in
                    let isSel = selectedLevel == lvl
                    Button { withAnimation(AppDesign.Animation.quick) { selectedLevel = lvl } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: lvl.iconName).font(.system(size: 12, weight: .semibold))
                            Text(appViewModel.localized(lvl.localizationKey)).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(isSel ? .white : lvl.color)
                        .padding(.horizontal, AppDesign.Spacing.md)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .fill(isSel ? lvl.color : lvl.color.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var dueDatePicker: some View {
        formField(icon: "calendar", label: appViewModel.localized("new_chore_due_date_label")) {
            DatePicker("", selection: $dueDate, in: minimumDueDate..., displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(accentOrange)
                .padding(.horizontal, AppDesign.Spacing.md)
                .padding(.vertical, AppDesign.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .fill(AppDesign.Colors.secondaryBackground)
                )
        }
    }

    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            HStack {
                sectionLabel(icon: "arrow.clockwise", text: appViewModel.localized("new_chore_recurring_label"))
                Spacer()
                Toggle("", isOn: $isRecurring).labelsHidden().tint(accentOrange)
            }
            if isRecurring {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(appViewModel.localized("new_chore_every_label"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                    TextField("7", text: $intervalText)
                        .keyboardType(.numberPad)
                        .font(AppDesign.Typography.bodyBold)
                        .multilineTextAlignment(.center)
                        .focused($focusedField, equals: .interval)
                        .frame(width: 56)
                        .padding(.vertical, 8)
                        .background(AppDesign.Colors.secondaryBackground)
                        .cornerRadius(AppDesign.CornerRadius.sm)
                        .onChange(of: intervalText) { _, val in recurringInterval = Int(val) ?? recurringInterval }
                    Text(appViewModel.localized("new_chore_days_label"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppDesign.Animation.quick, value: isRecurring)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Button { if !isCreating { requestDismiss() } } label: {
                Text(appViewModel.localized("common_cancel"))
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightSmall)
                    .background(AppDesign.Colors.secondaryBackground)
                    .cornerRadius(AppDesign.CornerRadius.md)
            }
            Button(action: submitChore) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    if isCreating {
                        ProgressView().scaleEffect(0.8).tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 16, weight: .semibold))
                    }
                    Text(appViewModel.localized("common_create")).font(AppDesign.Typography.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightSmall)
                .background(
                    canCreate
                        ? LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(AppDesign.CornerRadius.md)
            }
            .disabled(!canCreate || isCreating)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .background(AppDesign.Colors.background.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func formField<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(icon: icon, text: label)
            content()
        }
    }

    private func sectionLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(accentOrange)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    private func submitChore() {
        guard let memberId = selectedMember?.apiId, !houseId.isEmpty else { return }
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        isCreating = true
        Task {
            await appViewModel.createChore(
                assignedToId: memberId,
                description: description,
                dueDate: dueDate,
                houseId: houseId,
                isRecurring: isRecurring,
                level: selectedLevel,
                recurringInterval: isRecurring ? recurringInterval : 0,
                title: title.trimmingCharacters(in: .whitespaces)
            )
            isCreating = false
            requestDismiss()
        }
    }

    private func requestDismiss() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}

// MARK: - ChoreLevel UI Helpers

extension ChoreLevel {
    var iconName: String {
        switch self { case .easy: return "leaf.fill"; case .medium: return "flame.fill"; case .hard: return "bolt.fill" }
    }
    var color: Color {
        switch self {
        case .easy:   return Color(red: 0.2, green: 0.75, blue: 0.4)
        case .medium: return Color(red: 1.0, green: 0.48, blue: 0.15)
        case .hard:   return Color(red: 0.9, green: 0.2, blue: 0.25)
        }
    }
}

// MARK: - Preview

#Preview {
    NewChorePopup(appViewModel: AppViewModel(), onDismiss: {})
}
