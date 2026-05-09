import SwiftUI

private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

/// Premium chore detail sheet.
/// - Shows full status pipeline (Draft → Progress → InTest → Completed).
/// - Status update controls are only visible when the logged-in user is the assignee.
struct ChoreDetailPopup: View {
    let chore: Chore
    let appViewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var selectedStatus: ChoreStatus
    @State private var isUpdating: Bool = false

    init(chore: Chore, appViewModel: AppViewModel, onDismiss: @escaping () -> Void) {
        self.chore = chore
        self.appViewModel = appViewModel
        self.onDismiss = onDismiss
        _selectedStatus = State(initialValue: ChoreStatus(rawValue: chore.status) ?? .draft)
    }

    private var isAssignedToCurrentUser: Bool {
        guard let uid = appViewModel.currentUserId,
              let aid = chore.assignedToId else { return false }
        return uid == aid
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isUpdating { onDismiss() } }

            VStack(spacing: 0) {
                topBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        statusPipeline
                        infoSection
                        if isAssignedToCurrentUser {
                            statusUpdateSection
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xl)
                }
                .frame(maxHeight: 500)
                dismissButton
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

            if isUpdating {
                Color.black.opacity(0.25).ignoresSafeArea()
                VStack(spacing: AppDesign.Spacing.lg) {
                    ProgressView().scaleEffect(1.4).tint(.white)
                    Text("Updating…").font(AppDesign.Typography.subheadline).foregroundColor(.white)
                }
            }
        }
        .animation(AppDesign.Animation.standard, value: isUpdating)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            LinearGradient(
                colors: [accentOrange, accentOrange.opacity(0.7)],
                startPoint: .leading, endPoint: .trailing
            )
            // Background decorative icon
            Image(systemName: "house.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white.opacity(0.12))

            HStack(spacing: AppDesign.Spacing.sm) {
                // Level badge
                HStack(spacing: 4) {
                    Image(systemName: choreLevelObj.iconName)
                        .font(.system(size: 11, weight: .bold))
                    Text(choreLevelObj.displayName)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(choreLevelObj.color)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.white.opacity(0.92))
                .cornerRadius(AppDesign.CornerRadius.circle)

                Text(chore.title)
                    .font(AppDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button(action: onDismiss) {
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

    // MARK: - Status Pipeline

    private var statusPipeline: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            sectionLabel(icon: "arrow.triangle.2.circlepath", text: "Status")
            HStack(spacing: 0) {
                ForEach(Array([ChoreStatus.draft, .progress, .inTest, .completed].enumerated()), id: \.offset) { index, step in
                    let isCurrent = step.rawValue == chore.status
                    let isPast    = step.rawValue < chore.status

                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(isCurrent ? accentOrange : (isPast ? accentOrange.opacity(0.3) : AppDesign.Colors.secondaryBackground))
                                .frame(width: 32, height: 32)
                            Image(systemName: isPast ? "checkmark" : step.iconName)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isCurrent ? .white : (isPast ? accentOrange : AppDesign.Colors.textSecondary))
                        }
                        Text(step.displayName)
                            .font(.system(size: 10, weight: isCurrent ? .bold : .regular))
                            .foregroundColor(isCurrent ? accentOrange : AppDesign.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 60)
                    }

                    if index < 3 {
                        Rectangle()
                            .fill(step.rawValue < chore.status ? accentOrange.opacity(0.4) : AppDesign.Colors.secondaryBackground)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .offset(y: -10)
                    }
                }
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(accentOrange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            // Title + description
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                sectionLabel(icon: "text.badge.checkmark", text: "Task")
                Text(chore.title)
                    .font(AppDesign.Typography.title3)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                if !chore.description.isEmpty {
                    Text(chore.description)
                        .font(AppDesign.Typography.body)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                    .fill(AppDesign.Colors.secondaryBackground)
            )

            // Meta row
            HStack(spacing: AppDesign.Spacing.md) {
                // Assignee
                infoTile(icon: "person.fill", label: "Assigned To") {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        UserAvatar(user: chore.assignedTo, size: 28)
                        Text(chore.assignedTo.firstName)
                            .font(AppDesign.Typography.bodyBold)
                            .foregroundColor(AppDesign.Colors.textPrimary)
                    }
                }

                // Due date
                infoTile(icon: "calendar", label: "Due") {
                    Text(formattedDueDate)
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundColor(dueColor)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(dueColor.opacity(0.12))
                        .cornerRadius(AppDesign.CornerRadius.sm)
                }
            }
        }
    }

    // MARK: - Status Update Section (assignee only)

    private var statusUpdateSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionLabel(icon: "pencil.circle.fill", text: "Update Status")
            Text("Move this chore to the next stage.")
                .font(AppDesign.Typography.caption)
                .foregroundColor(AppDesign.Colors.textSecondary)

            // Status selector pills
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppDesign.Spacing.sm) {
                ForEach([ChoreStatus.draft, .progress, .inTest, .completed], id: \.rawValue) { step in
                    let isSel = selectedStatus == step
                    Button { withAnimation(AppDesign.Animation.quick) { selectedStatus = step } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: step.iconName).font(.system(size: 12, weight: .semibold))
                            Text(step.displayName).font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(isSel ? .white : step.color)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .fill(isSel ? step.color : step.color.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                        .stroke(isSel ? step.color : step.color.opacity(0.3), lineWidth: 1.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Save button
            let statusChanged = selectedStatus.rawValue != chore.status
            Button(action: saveStatus) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    if isUpdating {
                        ProgressView().scaleEffect(0.8).tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 16, weight: .semibold))
                    }
                    Text("Save Status").font(AppDesign.Typography.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightSmall)
                .background(
                    statusChanged
                        ? LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.gray.opacity(0.35), Color.gray.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(AppDesign.CornerRadius.md)
            }
            .disabled(!statusChanged || isUpdating)
        }
        .padding(AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(accentOrange.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Text("Close")
                .font(AppDesign.Typography.headline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightSmall)
                .background(AppDesign.Colors.secondaryBackground)
                .cornerRadius(AppDesign.CornerRadius.md)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .background(AppDesign.Colors.background.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4))
    }

    // MARK: - Helpers

    private func saveStatus() {
        guard let choreApiId = chore.choreApiId,
              let houseId = chore.houseId else { return }
        isUpdating = true
        Task {
            await appViewModel.updateChoreStatus(
                choreApiId: choreApiId,
                houseId: houseId,
                status: selectedStatus
            )
            isUpdating = false
            onDismiss()
        }
    }

    private var formattedDueDate: String {
        guard let rawDate = chore.dueDate else { return chore.dueLabel }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: rawDate) ?? ISO8601DateFormatter().date(from: rawDate)
        guard let date else { return chore.dueLabel }
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }

    private var dueColor: Color {
        switch chore.dueLabel {
        case "Overdue": return AppDesign.Colors.error
        case "Today":   return AppDesign.Colors.warning
        default:        return AppDesign.Colors.primary
        }
    }

    private var choreLevelObj: ChoreLevel {
        ChoreLevel(rawValue: chore.level) ?? .easy
    }

    private func sectionLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(accentOrange)
            .textCase(.uppercase)
            .tracking(0.5)
    }

    @ViewBuilder
    private func infoTile<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Label(label, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppDesign.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
        )
    }
}

// MARK: - ChoreStatus UI Helpers

extension ChoreStatus {
    var displayName: String {
        switch self {
        case .draft:     return "Draft"
        case .progress:  return "In Progress"
        case .inTest:    return "In Review"
        case .completed: return "Completed"
        }
    }
    var iconName: String {
        switch self {
        case .draft:     return "doc.fill"
        case .progress:  return "arrow.right.circle.fill"
        case .inTest:    return "magnifyingglass.circle.fill"
        case .completed: return "checkmark.seal.fill"
        }
    }
    var color: Color {
        switch self {
        case .draft:     return Color(red: 0.55, green: 0.55, blue: 0.6)
        case .progress:  return Color(red: 1.0, green: 0.48, blue: 0.15)
        case .inTest:    return Color(red: 0.5, green: 0.2, blue: 0.85)
        case .completed: return Color(red: 0.2, green: 0.75, blue: 0.4)
        }
    }
}

// MARK: - Preview

#Preview {
    ChoreDetailPopup(
        chore: Chore(
            choreApiId: "abc123",
            houseId: "house1",
            assignedToId: "user1",
            title: "Clean the kitchen",
            description: "Wipe down all surfaces and organize items",
            assignedTo: User(name: "John Doe", points: 12),
            dueLabel: "Today",
            status: 1,
            level: 20
        ),
        appViewModel: AppViewModel(),
        onDismiss: {}
    )
}
