import SwiftUI
import FausCrewCore

/// Second page of the catalog popup: the chosen template as an editable header, then who, when,
/// how often and how hard. Creates the chore through the regular create-chore endpoint. A system
/// template is read-only: "Save as draft" always adds a new draft of the user's (as it is or
/// tweaked). A draft opened from the Drafts tab is updated in place. A chore written from scratch,
/// or a draft, also picks its category.
struct ChoreTemplateEditorView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let template: ChoreTemplate
    let templateCategory: ChoreCategory
    let prefillTitle: String?
    let onBack: () -> Void
    let onClose: () -> Void
    let onCreated: (ChoreCatalogCreation) -> Void
    /// Sends the draft (`PUT chore/catalog`); returns the failure, if any.
    let onSaveDraft: (ChoreCatalogRecord) async -> ChoreCatalogFailure?

    private enum Field: Hashable {
        case title
        case detail
    }

    private enum DueChoice: Hashable {
        case today, tomorrow, weekend, custom
    }

    @State private var title = ""
    @State private var detail = ""
    @State private var selectedMemberId: String?
    @State private var level: ChoreLevel = .easy
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    /// Off: the chore is due at the end of the chosen day (00:00 that night).
    @State private var hasDueTime = false
    /// Only the hour and minute are read; the day comes from `dueDate`.
    @State private var dueTime = ChoreTemplateEditorView.defaultDueTime()
    @State private var repeatDays = 0
    @State private var isCustomRepeat = false
    @State private var isCreating = false
    @State private var isSavingDraft = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var selectedCategoryId = ""
    @FocusState private var focusedField: Field?

    private var isBlank: Bool { template.origin == .blank }
    /// Written by the user (blank card or draft): the category picker is shown.
    private var isCustom: Bool { isBlank || template.isDraft }
    /// The draft a save updates: only a draft opened from the Drafts tab. System templates are
    /// never updated; saving one adds a new draft.
    private var savedRecord: ChoreCatalogRecord? { template.isDraft ? template.record : nil }

    /// A custom chore follows the picked category; catalog templates keep their own.
    private var category: ChoreCategory {
        guard isCustom, let picked = ChoreCatalog.category(id: selectedCategoryId) else { return templateCategory }
        return picked
    }

    private var trimmedDetail: String { detail.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The draft as it would be sent now: the opened draft with its id, or a new record.
    private var draftSnapshot: ChoreCatalogRecord {
        var record = savedRecord ?? ChoreCatalogRecord(title: "", category: category.kind.rawValue)
        record.title = trimmedTitle
        record.description = trimmedDetail
        record.level = level.rawValue
        record.recurringInterval = repeatDays
        record.category = category.kind.rawValue
        return record
    }

    /// The server's rules (`ChoreCatalogRules`), and an update needs a change.
    private var canSaveDraft: Bool {
        guard !isCreating, !isSavingDraft, ChoreCatalogRules.violations(of: draftSnapshot).isEmpty else { return false }
        guard let savedRecord else { return true }
        return draftSnapshot != savedRecord
    }

    /// Why a typed draft cannot be saved yet; `nil` while the title is still empty.
    private var draftRuleHint: String? {
        if !trimmedTitle.isEmpty, !ChoreCatalogRules.isValidTitle(trimmedTitle) {
            return appViewModel.catalogText(
                "chore_catalog_editor_draft_title_rule",
                tr: "Taslak için iş adı 3–200 karakter olmalı.",
                en: "A draft needs a name of 3–200 characters."
            )
        }
        if !ChoreCatalogRules.isValidDescription(trimmedDetail) {
            return appViewModel.catalogText(
                "chore_catalog_editor_draft_detail_rule",
                tr: "Not en fazla 1000 karakter olabilir.",
                en: "The note can be at most 1000 characters."
            )
        }
        return nil
    }
    private var members: [User] { appViewModel.dashboardMembers }
    private var houseId: String { appViewModel.currentHouseDetails?.id ?? "" }
    private var selectedMember: User? { members.first { $0.id == selectedMemberId } }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canCreate: Bool {
        !trimmedTitle.isEmpty && selectedMember?.apiId != nil && !houseId.isEmpty && !isCreating && !isSavingDraft
            && !isDueTimeInPast
    }

    /// The moment sent to the backend (`ChoreDueDate`: end of day unless a time is picked).
    private var resolvedDueDate: Date {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: dueTime)
        return ChoreDueDate.resolve(day: dueDate, hour: hasDueTime ? parts.hour : nil, minute: parts.minute)
    }

    private var isDueTimeInPast: Bool {
        hasDueTime && resolvedDueDate <= Date()
    }

    /// 18:00, or the next full hour when the evening has already started (at most 23:00).
    private static func defaultDueTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = min(max(18, calendar.component(.hour, from: now) + 1), 23)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }

    private static func timeText(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: AppDesign.Spacing.md) {
                    if isCustom {
                        categorySection
                    }
                    memberSection
                    dueSection
                    repeatSection
                    levelSection
                    draftButton
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.top, AppDesign.Spacing.lg)
                .padding(.bottom, AppDesign.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)

            bottomBar
        }
        .tint(category.tint)
        .onAppear(perform: loadTemplate)
        .animation(AppDesign.Animation.quick, value: errorMessage)
    }

    // MARK: - Header

    /// Full-bleed theme header: navigation, meta pills and the editable title and note.
    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Button {
                    focusedField = nil
                    onBack()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Text(appViewModel.catalogText("chore_catalog_editor_back", tr: "Katalog", en: "Catalog"))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.leading, 10)
                    .padding(.trailing, 12)
                    .frame(height: 32)
                    .background(.white.opacity(0.2), in: Capsule())
                }
                .buttonStyle(CatalogPressStyle())

                Spacer(minLength: 0)

                Text(template.isDraft
                     ? appViewModel.catalogText("chore_catalog_editor_draft_title", tr: "Taslağı düzenle", en: "Edit draft")
                     : isBlank
                     ? appViewModel.catalogText("chore_catalog_editor_blank_title", tr: "Yeni iş", en: "New chore")
                     : appViewModel.catalogText("chore_catalog_editor_title", tr: "İşi hazırla", en: "Set up the chore"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .textCase(.uppercase)
                    .tracking(0.6)

                Spacer(minLength: 0)

                Button {
                    focusedField = nil
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.2), in: Circle())
                }
                .buttonStyle(CatalogPressStyle())
                .accessibilityLabel(appViewModel.localized("common_close", fallback: "Close"))
            }

            HStack(spacing: AppDesign.Spacing.sm) {
                HStack(spacing: 5) {
                    Image(systemName: category.icon)
                        .font(.system(size: 11, weight: .bold))
                    Text(appViewModel.catalogName(category))
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(category.deep)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white, in: Capsule())

                Spacer(minLength: 0)
            }
            .padding(.top, AppDesign.Spacing.xs)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                editableBox(
                    label: appViewModel.catalogText("chore_catalog_editor_title_label", tr: "İş adı", en: "Chore name"),
                    field: .title
                ) {
                    TextField(
                        "",
                        text: $title,
                        prompt: Text(appViewModel.catalogText("chore_catalog_editor_title_placeholder", tr: "İşin adını yaz", en: "Name the chore"))
                            .foregroundStyle(.white.opacity(0.55)),
                        axis: .vertical
                    )
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .lineLimit(1...2)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .detail }
                }

                editableBox(
                    label: appViewModel.catalogText("chore_catalog_editor_detail_label", tr: "Not", en: "Note"),
                    field: .detail
                ) {
                    TextField(
                        "",
                        text: $detail,
                        prompt: Text(appViewModel.catalogText("chore_catalog_editor_detail_placeholder", tr: "Kısa bir not ekle (isteğe bağlı)", en: "Add a short note (optional)"))
                            .foregroundStyle(.white.opacity(0.55)),
                        axis: .vertical
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .detail)
                }
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.top, AppDesign.Spacing.lg)
        .padding(.bottom, AppDesign.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Same theme header as the catalog; the category shows only in the small pill.
            BrandPopupHeaderBackground(topCornerRadius: 30)
                .accessibilityHidden(true)
        }
    }

    /// A glassy, clearly editable box on the header: an uppercase label with a pencil,
    /// the field, and a border that turns solid while typing. Tapping anywhere in it focuses it.
    private func editableBox<Field_: View>(
        label: String,
        field: Field,
        @ViewBuilder content: () -> Field_
    ) -> some View {
        let isFocused = focusedField == field
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.8)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Image(systemName: isFocused ? "keyboard" : "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .foregroundStyle(.white.opacity(isFocused ? 0.95 : 0.75))
            .accessibilityHidden(true)

            content()
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .padding(.vertical, 10)
        .background(shape.fill(.white.opacity(isFocused ? 0.24 : 0.14)))
        .overlay(
            shape.strokeBorder(
                .white.opacity(isFocused ? 0.85 : 0.4),
                style: isFocused
                    ? StrokeStyle(lineWidth: 1.5)
                    : StrokeStyle(lineWidth: 1, dash: [5, 4])
            )
        )
        .contentShape(shape)
        .onTapGesture { focusedField = field }
        .animation(AppDesign.Animation.quick, value: isFocused)
    }

    // MARK: - Who

    private var memberSection: some View {
        editorSection(
            icon: "person.fill",
            title: appViewModel.catalogText("chore_catalog_editor_who", tr: "Kim yapacak?", en: "Who's on it?")
        ) {
            if members.isEmpty {
                Text(appViewModel.catalogText("chore_catalog_editor_no_members", tr: "Evde henüz atanabilecek kimse yok.", en: "There's no one to assign yet."))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        ForEach(members) { member in
                            memberButton(member)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, AppDesign.Spacing.lg, for: .scrollContent)
                .padding(.horizontal, -AppDesign.Spacing.lg)
            }
        }
    }

    private func memberButton(_ member: User) -> some View {
        let isSelected = member.id == selectedMemberId
        let isMe = member.apiId != nil && member.apiId == appViewModel.currentUser?.apiId
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                selectedMemberId = member.id
            }
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    UserAvatar(user: member, size: 48)
                        .padding(3)
                        .overlay(Circle().strokeBorder(isSelected ? category.tint : Color.clear, lineWidth: 2.5))
                        .scaleEffect(isSelected ? 1.0 : 0.94)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(category.tint, in: Circle())
                            .overlay(Circle().strokeBorder(AppDesign.Colors.cardBackground, lineWidth: 2))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(isMe ? appViewModel.catalogText("chore_catalog_editor_me", tr: "Ben", en: "Me") : member.firstName)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? AppDesign.Colors.textPrimary : AppDesign.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 66)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? category.tint.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(CatalogPressStyle())
        .accessibilityLabel(member.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - When

    private var dueChoice: DueChoice {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(dueDate, inSameDayAs: today) { return .today }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            return .tomorrow
        }
        if calendar.isDate(dueDate, inSameDayAs: weekendDate) { return .weekend }
        return .custom
    }

    /// Today on a weekend, otherwise the coming Saturday.
    private var weekendDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDateInWeekend(today) { return today }
        return calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime) ?? today
    }

    private var dueSection: some View {
        editorSection(
            icon: "calendar",
            title: appViewModel.catalogText("chore_catalog_editor_when", tr: "Ne zaman?", en: "When?")
        ) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    dueChip(.today, label: appViewModel.localized("common_today", fallback: "Today"), date: Calendar.current.startOfDay(for: Date()))
                    dueChip(.tomorrow, label: appViewModel.catalogText("chore_catalog_editor_tomorrow", tr: "Yarın", en: "Tomorrow"),
                            date: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date())
                    if !Calendar.current.isDateInWeekend(Date()) {
                        dueChip(.weekend, label: appViewModel.catalogText("chore_catalog_editor_weekend", tr: "Hafta sonu", en: "Weekend"), date: weekendDate)
                    }
                }

                HStack {
                    Label(
                        appViewModel.catalogText("chore_catalog_editor_pick_date", tr: "Başka bir gün", en: "Another day"),
                        systemImage: dueChoice == .custom ? "checkmark.circle.fill" : "calendar.badge.plus"
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(dueChoice == .custom ? category.tint : AppDesign.Colors.textSecondary)
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { dueDate },
                            set: { dueDate = Calendar.current.startOfDay(for: $0) }
                        ),
                        in: Calendar.current.startOfDay(for: Date())...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                }

                Rectangle()
                    .fill(AppDesign.Colors.hairline)
                    .frame(height: 0.5)
                    .padding(.vertical, 2)

                timePicker
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: hasDueTime)
            .animation(AppDesign.Animation.quick, value: isDueTimeInPast)
        }
    }

    // MARK: Due time

    private static let quickHours = [9, 12, 15, 18, 21]

    private var timePicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text(appViewModel.catalogText("chore_catalog_editor_due_time", tr: "Bitiş saati", en: "Due by"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppDesign.Colors.textSecondary)

            HStack(spacing: AppDesign.Spacing.sm) {
                timeModeCard(
                    isSelected: !hasDueTime,
                    icon: "moon.stars.fill",
                    title: appViewModel.catalogText("chore_catalog_editor_end_of_day", tr: "Gün sonu", en: "End of day"),
                    value: "00:00"
                ) {
                    hasDueTime = false
                }
                timeModeCard(
                    isSelected: hasDueTime,
                    icon: "clock.fill",
                    title: appViewModel.catalogText("chore_catalog_editor_pick_time", tr: "Saat seç", en: "Pick a time"),
                    value: hasDueTime ? Self.timeText(dueTime) : "--:--"
                ) {
                    if Self.isPast(hour: Calendar.current.component(.hour, from: dueTime),
                                   minute: Calendar.current.component(.minute, from: dueTime),
                                   on: dueDate) {
                        dueTime = Self.defaultDueTime()
                    }
                    hasDueTime = true
                }
            }

            if hasDueTime {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    HStack(spacing: 6) {
                        ForEach(Self.quickHours, id: \.self) { hour in
                            quickTimeChip(hour: hour)
                        }
                    }

                    HStack {
                        Label(
                            appViewModel.catalogText("chore_catalog_editor_exact_time", tr: "Tam saat", en: "Exact time"),
                            systemImage: "clock.badge"
                        )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        Spacer()
                        DatePicker("", selection: $dueTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .environment(\.locale, Locale(identifier: "tr_TR"))
                    }

                    if isDueTimeInPast {
                        Label(
                            appViewModel.catalogText("chore_catalog_editor_time_past", tr: "Bu saat geçti, ileri bir saat seç.", en: "That time has passed, pick a later one."),
                            systemImage: "exclamationmark.circle.fill"
                        )
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppDesign.Colors.error)
                        .transition(.opacity)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                Text(appViewModel.catalogText(
                    "chore_catalog_editor_end_of_day_hint",
                    tr: "Saat seçmezsen iş, seçtiğin günün sonuna (gece 00:00) kadar açık kalır.",
                    en: "Without a time, the chore stays open until the end of the chosen day (midnight)."
                ))
                .font(.system(size: 12))
                .foregroundStyle(AppDesign.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
            }
        }
    }

    private func timeModeCard(isSelected: Bool, icon: String, title: String, value: String, action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { action() }
        } label: {
            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 30, height: 30)
                    .background((isSelected ? Color.white.opacity(0.22) : category.tint.opacity(0.12)), in: Circle())
                    .foregroundStyle(isSelected ? .white : category.tint)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(value)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(isSelected ? .white : AppDesign.Colors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(category.gradient) : AnyShapeStyle(AppDesign.Colors.secondaryBackground))
            }
        }
        .buttonStyle(CatalogPressStyle(scale: 0.96))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func quickTimeChip(hour: Int) -> some View {
        let calendar = Calendar.current
        let isSelected = calendar.component(.hour, from: dueTime) == hour && calendar.component(.minute, from: dueTime) == 0
        let isPast = Self.isPast(hour: hour, minute: 0, on: dueDate)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy) {
                dueTime = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? dueTime
            }
        } label: {
            Text(String(format: "%02d:00", hour))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected ? .white : AppDesign.Colors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    Capsule().fill(isSelected ? AnyShapeStyle(category.gradient) : AnyShapeStyle(AppDesign.Colors.secondaryBackground))
                }
                .opacity(isPast ? 0.35 : 1)
        }
        .buttonStyle(CatalogPressStyle(scale: 0.94))
        .disabled(isPast)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func isPast(hour: Int, minute: Int, on day: Date) -> Bool {
        let moment = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return moment <= Date()
    }

    private func dueChip(_ choice: DueChoice, label: String, date: Date) -> some View {
        let isSelected = dueChoice == choice
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dueDate = date }
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(size: 11, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundStyle(isSelected ? .white : AppDesign.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(category.gradient) : AnyShapeStyle(AppDesign.Colors.secondaryBackground))
            }
        }
        .buttonStyle(CatalogPressStyle(scale: 0.96))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - How often

    private var repeatSection: some View {
        editorSection(
            icon: "arrow.clockwise",
            title: appViewModel.catalogText("chore_catalog_editor_repeat", tr: "Ne sıklıkla?", en: "How often?"),
            trailing: template.repeatDays > 0 && !isCustom
                ? appViewModel.catalogText("chore_catalog_editor_suggested", tr: "Önerilen: {value}", en: "Suggested: {value}")
                    .replacingOccurrences(of: "{value}", with: appViewModel.catalogRepeatLabel(template.repeatDays))
                : nil
        ) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                FlowLayout(spacing: AppDesign.Spacing.sm) {
                    ForEach(ChoreRepeatPreset.all, id: \.self) { days in
                        repeatChip(
                            label: appViewModel.catalogRepeatLabel(days),
                            isSelected: !isCustomRepeat && repeatDays == days,
                            isSuggested: !isCustom && days == template.repeatDays
                        ) {
                            isCustomRepeat = false
                            repeatDays = days
                        }
                    }
                    repeatChip(
                        label: appViewModel.catalogText("chore_catalog_repeat_custom", tr: "Özel", en: "Custom"),
                        icon: "slider.horizontal.3",
                        isSelected: isCustomRepeat,
                        isSuggested: false
                    ) {
                        isCustomRepeat = true
                        if repeatDays < 1 { repeatDays = 4 }
                    }
                }

                if isCustomRepeat {
                    HStack {
                        Text(appViewModel.catalogRepeatLabel(repeatDays))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppDesign.Colors.textPrimary)
                            .contentTransition(.numericText())
                        Spacer()
                        Stepper("", value: $repeatDays, in: 1...90)
                            .labelsHidden()
                    }
                    .padding(.horizontal, AppDesign.Spacing.md)
                    .padding(.vertical, AppDesign.Spacing.sm)
                    .background(AppDesign.Colors.secondaryBackground, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isCustomRepeat)
            .animation(.snappy, value: repeatDays)
        }
    }

    private func repeatChip(label: String, icon: String? = nil, isSelected: Bool, isSuggested: Bool, action: @escaping () -> Void) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { action() }
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if isSuggested && !isSelected {
                    Image(systemName: "sparkle")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(category.tint)
                }
            }
            .foregroundStyle(isSelected ? .white : AppDesign.Colors.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background {
                if isSelected {
                    Capsule().fill(category.gradient)
                } else {
                    Capsule().fill(AppDesign.Colors.secondaryBackground)
                        .overlay(Capsule().strokeBorder(isSuggested ? category.tint.opacity(0.45) : Color.clear, lineWidth: 1))
                }
            }
        }
        .buttonStyle(CatalogPressStyle(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Difficulty

    private var levelSection: some View {
        editorSection(
            icon: "flame.fill",
            title: appViewModel.localized("new_chore_difficulty_label", fallback: "Difficulty")
        ) {
            HStack(spacing: AppDesign.Spacing.sm) {
                ForEach([ChoreLevel.easy, .medium, .hard], id: \.rawValue) { item in
                    let isSelected = level == item
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { level = item }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: item.iconName)
                                .font(.system(size: 16, weight: .semibold))
                                .symbolEffect(.bounce, value: isSelected)
                            Text(appViewModel.localized(item.localizationKey))
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? .white : item.color)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                                .fill(isSelected ? item.color : item.color.opacity(0.12))
                        )
                    }
                    .buttonStyle(CatalogPressStyle(scale: 0.96))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Category (custom chores)

    private var categorySection: some View {
        editorSection(
            icon: "square.grid.2x2.fill",
            title: appViewModel.catalogText("chore_catalog_editor_category", tr: "Kategori", en: "Category")
        ) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        ForEach(ChoreCatalog.categories) { item in
                            categoryChip(item)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, AppDesign.Spacing.lg, for: .scrollContent)
                .padding(.horizontal, -AppDesign.Spacing.lg)
                .onAppear { proxy.scrollTo(category.id, anchor: .center) }
            }
        }
    }

    private func categoryChip(_ item: ChoreCategory) -> some View {
        let isSelected = item.id == category.id
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selectedCategoryId = item.id }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isSelected ? .white : item.tint)
                Text(appViewModel.catalogName(item))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : AppDesign.Colors.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background {
                Capsule().fill(isSelected ? AnyShapeStyle(item.gradient) : AnyShapeStyle(AppDesign.Colors.secondaryBackground))
            }
        }
        .buttonStyle(CatalogPressStyle(scale: 0.95))
        .id(item.id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Draft (every card)

    /// "Save as draft" (a new draft), or "Update draft" for a draft opened from the Drafts tab.
    private var draftButton: some View {
        let isUpdate = savedRecord != nil
        let enabled = canSaveDraft
        return VStack(spacing: AppDesign.Spacing.xs) {
            Button(action: saveDraft) {
                HStack(spacing: 8) {
                    if isSavingDraft {
                        ProgressView()
                            .controlSize(.small)
                            .tint(category.deep)
                    } else {
                        Image(systemName: isUpdate ? "arrow.triangle.2.circlepath" : "tray.and.arrow.down.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(isUpdate
                         ? appViewModel.catalogText("chore_catalog_editor_update_draft", tr: "Taslağı güncelle", en: "Update draft")
                         : appViewModel.catalogText("chore_catalog_editor_save_draft", tr: "Taslak olarak kaydet", en: "Save as draft"))
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(enabled || isSavingDraft ? category.deep : AppDesign.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    Capsule().fill(enabled ? category.tint.opacity(0.12) : AppDesign.Colors.secondaryBackground)
                )
                .overlay(
                    Capsule().strokeBorder(enabled ? category.tint.opacity(0.55) : Color.clear,
                                           style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                )
            }
            .buttonStyle(CatalogPressStyle(scale: 0.97))
            .disabled(!enabled)
            .animation(AppDesign.Animation.quick, value: enabled)
            .accessibilityHint(appViewModel.catalogText(
                "chore_catalog_editor_draft_hint",
                tr: "Taslaklar sekmesinde saklanır; istediğin zaman tekrar kullanabilirsin.",
                en: "Kept in Drafts so you can reuse it any time."
            ))

            if let draftRuleHint {
                Text(draftRuleHint)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(AppDesign.Animation.quick, value: draftRuleHint)
    }

    private func saveDraft() {
        guard canSaveDraft else { return }
        focusedField = nil
        errorMessage = nil
        isSavingDraft = true
        let record = draftSnapshot
        Task { @MainActor in
            let failure = await onSaveDraft(record)
            isSavingDraft = false
            guard let failure else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            errorMessage = failure.message ?? appViewModel.catalogText(
                "chore_catalog_editor_draft_error",
                tr: "Taslak kaydedilemedi. Bağlantını kontrol edip tekrar dene.",
                en: "Couldn't save the draft. Check your connection and try again."
            )
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppDesign.Colors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: AppDesign.Spacing.md) {
                if let member = selectedMember {
                    UserAvatar(user: member, size: 34)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(trimmedTitle.isEmpty
                         ? appViewModel.catalogText("chore_catalog_editor_untitled", tr: "İsimsiz iş", en: "Untitled chore")
                         : trimmedTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(trimmedTitle.isEmpty ? AppDesign.Colors.textTertiary : AppDesign.Colors.textPrimary)
                        .lineLimit(1)
                    Text(summaryLine)
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                Spacer(minLength: AppDesign.Spacing.sm)

                Button(action: create) {
                    HStack(spacing: 6) {
                        if isCreating {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .heavy))
                        }
                        Text(appViewModel.catalogText("chore_catalog_editor_create", tr: "Ekle", en: "Add"))
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .frame(height: 48)
                    .background {
                        Capsule().fill(canCreate || isCreating
                            ? AnyShapeStyle(category.gradient)
                            : AnyShapeStyle(AppDesign.Colors.textTertiary.opacity(0.45)))
                    }
                    .shadow(color: canCreate ? category.deep.opacity(0.35) : .clear, radius: 8, x: 0, y: 4)
                }
                .buttonStyle(CatalogPressStyle(scale: 0.95))
                .disabled(!canCreate)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
        .background {
            Rectangle()
                .fill(AppDesign.Colors.popupBackground)
                .shadow(color: AppDesign.Colors.shadow.opacity(0.08), radius: 10, x: 0, y: -4)
        }
    }

    /// "Ayşe · Tomorrow · Every day"
    private var summaryLine: String {
        let who = selectedMember.map { member in
            member.apiId != nil && member.apiId == appViewModel.currentUser?.apiId
                ? appViewModel.catalogText("chore_catalog_editor_me", tr: "Ben", en: "Me")
                : member.firstName
        } ?? appViewModel.catalogText("chore_catalog_editor_nobody", tr: "Kişi seç", en: "Pick someone")
        let when: String
        switch dueChoice {
        case .today: when = appViewModel.localized("common_today", fallback: "Today")
        case .tomorrow: when = appViewModel.catalogText("chore_catalog_editor_tomorrow", tr: "Yarın", en: "Tomorrow")
        case .weekend, .custom: when = dueDate.formatted(.dateTime.day().month(.abbreviated))
        }
        let whenWithTime = hasDueTime
            ? "\(when) \(Self.timeText(dueTime))"
            : "\(when) 00:00"
        return [who, whenWithTime, appViewModel.catalogRepeatLabel(repeatDays)].joined(separator: " · ")
    }

    // MARK: - Section chrome

    private func editorSection<Content: View>(
        icon: String,
        title: String,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(category.tint)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer(minLength: 0)
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(category.tint)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(AppDesign.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous)
                .fill(AppDesign.Colors.cardBackground)
                .shadow(color: AppDesign.Shadow.light.color, radius: AppDesign.Shadow.light.radius, x: 0, y: AppDesign.Shadow.light.y)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous)
                .strokeBorder(AppDesign.Colors.hairline, lineWidth: 0.5)
        )
    }

    // MARK: - Actions

    private func loadTemplate() {
        guard !didLoad else { return }
        didLoad = true
        selectedCategoryId = templateCategory.id
        title = prefillTitle ?? (isBlank ? "" : appViewModel.catalogTitle(template))
        detail = isBlank ? "" : appViewModel.catalogDetail(template)
        level = template.level
        repeatDays = template.repeatDays
        // A custom interval that isn't a preset opens with the stepper.
        isCustomRepeat = repeatDays > 0 && !ChoreRepeatPreset.all.contains(repeatDays)
        let myId = appViewModel.currentUser?.apiId
        selectedMemberId = (members.first { $0.apiId != nil && $0.apiId == myId } ?? members.first)?.id
        if isBlank && prefillTitle == nil {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                focusedField = .title
            }
        }
    }

    private func create() {
        guard canCreate, let member = selectedMember, let memberId = member.apiId else { return }
        focusedField = nil
        errorMessage = nil
        isCreating = true
        let createdTitle = trimmedTitle
        let days = repeatDays
        Task { @MainActor in
            let success = await appViewModel.createChore(
                assignedToId: memberId,
                description: detail.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: resolvedDueDate,
                houseId: houseId,
                isRecurring: days > 0,
                level: level,
                recurringInterval: days,
                title: createdTitle,
                category: category.kind
            )
            isCreating = false
            if success {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                let isMe = member.apiId == appViewModel.currentUser?.apiId
                onCreated(ChoreCatalogCreation(
                    templateId: template.id,
                    title: createdTitle,
                    memberName: isMe ? appViewModel.catalogText("chore_catalog_editor_me", tr: "Ben", en: "Me") : member.firstName,
                    repeatDays: days
                ))
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                errorMessage = appViewModel.catalogText(
                    "chore_catalog_editor_error",
                    tr: "İş eklenemedi. Bağlantını kontrol edip tekrar dene.",
                    en: "Couldn't add the chore. Check your connection and try again."
                )
            }
        }
    }
}

// MARK: - Flow layout

/// Wraps chips onto as many rows as they need.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? maxX, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
