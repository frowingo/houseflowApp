import SwiftUI
import FausCrewCore

/// The day a chore is due, as the editor's quick chips know it.
enum ChoreDueChoice: Hashable {
    case today, tomorrow, weekend, custom

    init(dueDate: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(dueDate, inSameDayAs: today) {
            self = .today
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today), calendar.isDate(dueDate, inSameDayAs: tomorrow) {
            self = .tomorrow
        } else if calendar.isDate(dueDate, inSameDayAs: Self.weekendDate) {
            self = .weekend
        } else {
            self = .custom
        }
    }

    /// Today on a weekend, otherwise the coming Saturday.
    static var weekendDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if calendar.isDateInWeekend(today) { return today }
        return calendar.nextDate(after: today, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime) ?? today
    }
}

/// The "When?" section of the template editor: the day (quick chips or a date picker) and
/// either the end of that day or a picked time.
struct ChoreDueEditor: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let category: ChoreCategory
    @Binding var dueDate: Date
    /// Off: the chore is due at the end of the chosen day (00:00 that night).
    @Binding var hasDueTime: Bool
    /// Only the hour and minute are read; the day comes from `dueDate`.
    @Binding var dueTime: Date
    let isDueTimeInPast: Bool

    private var dueChoice: ChoreDueChoice { ChoreDueChoice(dueDate: dueDate) }

    /// 18:00, or the next full hour when the evening has already started (at most 23:00).
    static func defaultDueTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let hour = min(max(18, calendar.component(.hour, from: now) + 1), 23)
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: now) ?? now
    }

    static func timeText(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(spacing: AppDesign.Spacing.sm) {
                dueChip(.today, label: appViewModel.localized("common_today", fallback: "Today"), date: Calendar.current.startOfDay(for: Date()))
                dueChip(.tomorrow, label: appViewModel.catalogText("chore_catalog_editor_tomorrow", tr: "Yarın", en: "Tomorrow"),
                        date: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date())) ?? Date())
                if !Calendar.current.isDateInWeekend(Date()) {
                    dueChip(.weekend, label: appViewModel.catalogText("chore_catalog_editor_weekend", tr: "Hafta sonu", en: "Weekend"), date: ChoreDueChoice.weekendDate)
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

    private func dueChip(_ choice: ChoreDueChoice, label: String, date: Date) -> some View {
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
}
