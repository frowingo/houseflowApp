import SwiftUI
import FausCrewCore

/// The dashboard's chore list under a plain "Active Chores" title: active chores first,
/// closed ones after as history, and a catalog prompt when nothing is listed.
struct TodaysChoresCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let chores: [Chore]
    let onChoreDetailTap: (Chore) -> Void
    /// Opens the chore catalog (header button when chores are listed, empty-state button otherwise);
    /// `nil` hides both.
    var onAddChore: (() -> Void)? = nil
    /// Opens the chore archive; `nil` hides the entry row.
    var onOpenArchive: (() -> Void)? = nil

    var todaysChores: [Chore] {
        chores
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection
            
            Divider().overlay(AppDesign.Colors.separator)
                .padding(.horizontal, AppDesign.Spacing.xl)
            
            // Chores Content
            if todaysChores.isEmpty {
                emptyStateView
            } else {
                choresListView
            }

            // Older history lives in the archive, so the row stays even when the list is empty.
            if let onOpenArchive {
                archiveEntryRow(onOpenArchive)
            }
        }
        .background(
            ZStack {
                // Glassmorphism base
                AppDesign.Colors.cardBackground
                FausCardSheen()

                // Gradient overlay
                LinearGradient(
                    colors: [
                        AppDesign.Colors.primary.opacity(0.05),
                        Color.clear,
                        AppDesign.Colors.secondary.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .cornerRadius(AppDesign.CornerRadius.xl)
        .shadow(
            color: AppDesign.Shadow.medium.color,
            radius: AppDesign.Shadow.medium.radius,
            x: AppDesign.Shadow.medium.x,
            y: AppDesign.Shadow.medium.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(
                    LinearGradient(
                        colors: [
                            AppDesign.Colors.primary.opacity(0.3),
                            AppDesign.Colors.secondary.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
    
    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            // Same badge shape as House Members' header, in this card's indigo → teal order.
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            colors: [HouseJourneyTheme.indigo, HouseJourneyTheme.teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Circle()
                    .fill(HouseJourneyTheme.accentOrange)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(AppDesign.Colors.cardBackground, lineWidth: 1.5))
                    .offset(x: 15, y: 15)
            }
            .accessibilityHidden(true)

            Text(appViewModel.localized("active_chores_title", tr: "Aktif Görevler", en: "Active Chores"))
                .font(AppDesign.Typography.headline)
                .foregroundColor(AppDesign.Colors.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: AppDesign.Spacing.sm)

            // The empty state already carries its own catalog button.
            if let onAddChore, !todaysChores.isEmpty {
                ChoreCatalogMosaicButton(action: onAddChore)
            }
        }
        .frame(minHeight: 48)
        .padding(AppDesign.Spacing.xl)
    }

    // MARK: - Chores List
    
    /// Active chores first; Completed and Failed (and unknown) follow as the history.
    private var choresListView: some View {
        let active = todaysChores.activeChores
        let history = todaysChores.historyChores
        return LazyVStack(spacing: AppDesign.Spacing.md) {
            ForEach(active) { chore in
                choreRow(chore)
            }
            if !history.isEmpty {
                if !active.isEmpty {
                    Text(appViewModel.choreHistoryLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppDesign.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppDesign.Spacing.xs)
                        .accessibilityAddTraits(.isHeader)
                }
                ForEach(history) { chore in
                    choreRow(chore)
                }
            }
        }
        .padding(AppDesign.Spacing.xl)
    }

    private func choreRow(_ chore: Chore) -> some View {
        ModernChoreRow(
            chore: chore,
            onTap: {
                onChoreDetailTap(chore)
            }
        )
    }
    
    private func archiveEntryRow(_ action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(AppDesign.Colors.separator)
                .padding(.horizontal, AppDesign.Spacing.xl)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                action()
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 14, weight: .semibold))
                    Text(appViewModel.localized("chore_archive_entry", tr: "Tüm geçmiş", en: "Full history"))
                        .font(AppDesign.Typography.subheadline.weight(.semibold))
                    Spacer(minLength: AppDesign.Spacing.sm)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            ZStack {
                // Gradient background circles
                Circle()
                    .fill(HouseJourneyTheme.indigo.opacity(0.18))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)

                Circle()
                    .fill(HouseJourneyTheme.teal.opacity(0.25))
                    .frame(width: 90, height: 90)
                    .scaleEffect(1.2)
                    .blur(radius: 15)

                // An empty list is not "all done": the icon invites adding, it does not celebrate.
                Image(systemName: "list.clipboard")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [HouseJourneyTheme.indigo, HouseJourneyTheme.teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: AppDesign.Spacing.sm) {
                Text(appViewModel.localized("active_chores_empty_title", tr: "Şu anda aktif bir iş yok", en: "No active chores right now"))
                    .font(AppDesign.Typography.title3)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                
                Text(appViewModel.localized("active_chores_empty_subtitle", tr: "Eklemeye ne dersin?", en: "How about adding one?"))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let onAddChore {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onAddChore()
                } label: {
                    Label(
                        appViewModel.catalogText("todays_tasks_empty_add", tr: "Katalogdan iş ekle", en: "Add from the catalog"),
                        systemImage: "square.grid.2x2.fill"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(height: 38)
                    .background(HouseJourneyTheme.accentOrange.opacity(0.12), in: Capsule())
                }
                .buttonStyle(CatalogPressStyle(scale: 0.96))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.huge)
    }
    
    // MARK: - Helper Methods
    // Removed helper methods as they're no longer needed
}

// MARK: - Modern Chore Row

struct ModernChoreRow: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let chore: Chore
    let onTap: () -> Void
    /// An extra line under the assignee row (the archive's closing info); `nil` leaves the row as is.
    var detail: String? = nil

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: AppDesign.Spacing.lg) {
                // Status indicator with pulse
                let choreStatus = chore.choreStatus
                let isCompleted = choreStatus == .completed
                // Failed reads as closed but not done: muted title, no strikethrough.
                let isClosed = choreStatus.listGroup.isHistory
                ZStack {
                    if !isCompleted {
                        Circle()
                            .fill(choreStatus.color.opacity(0.15))
                            .frame(width: 32, height: 32)
                    }

                    Image(systemName: isCompleted ? "checkmark.circle.fill" : choreStatus.iconName)
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: isCompleted ?
                                    [AppDesign.Colors.success, AppDesign.Colors.secondary] :
                                    [choreStatus.color, choreStatus.color.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isCompleted ? 0 : -15))
                }
                .frame(width: 32)

                // Task details
                VStack(alignment: .leading, spacing: 4) {
                    ChoreCategoryTag(kind: chore.categoryKind)

                    Text(chore.title)
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundColor(isClosed ? AppDesign.Colors.textSecondary : AppDesign.Colors.textPrimary)
                        .strikethrough(isCompleted)
                        .lineLimit(2)

                    HStack(spacing: AppDesign.Spacing.sm) {
                        UserAvatar(user: chore.assignedTo, size: 20)

                        Text(chore.assignedTo.name)
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer(minLength: AppDesign.Spacing.xs)

                        // Status badge
                        HStack(spacing: 4) {
                            Image(systemName: choreStatus.iconName)
                                .font(.system(size: 9, weight: .bold))
                            Text(appViewModel.statusLabel(choreStatus))
                                .font(AppDesign.Typography.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .allowsTightening(true)
                        }
                        .foregroundColor(choreStatus.color)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(choreStatus.color.opacity(0.12))
                        .clipShape(Capsule())
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                    }

                    if let detail {
                        Text(detail)
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(choreStatus.color.opacity(0.72))
                    .frame(width: 26, height: 26)
                    .background(choreStatus.color.opacity(0.10))
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(ModernChoreRowButtonStyle(accentColor: choreStatusObj.color))
    }
    
    private var choreStatusObj: ChoreStatus {
        chore.choreStatus
    }
}

private struct ModernChoreRowButtonStyle: ButtonStyle {
    let accentColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(AppDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .fill(AppDesign.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(
                                accentColor.opacity(configuration.isPressed ? 0.42 : 0.12),
                                lineWidth: configuration.isPressed ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: accentColor.opacity(configuration.isPressed ? 0.16 : 0.07),
                        radius: configuration.isPressed ? 5 : 9,
                        x: 0,
                        y: configuration.isPressed ? 2 : 5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#if DEBUG
// MARK: - Previews

#Preview("With Chores") {
    let viewModel = AppViewModel.preview
    viewModel.chores = [
        Chore(title: "Clean kitchen", description: "Wipe surfaces", assignedTo: User(name: "John", points: 10), dueLabel: "Today"),
        Chore(title: "Take out trash", description: "Empty bins", assignedTo: User(name: "Jane", points: 8), dueLabel: "Today"),
        Chore(title: "Vacuum", description: "Living room", assignedTo: User(name: "Bob", points: 12), dueLabel: "Overdue")
    ]
    
    return TodaysChoresCard(
        chores: viewModel.chores,
        onChoreDetailTap: { _ in }
    )
    .padding()
    .environmentObject(viewModel)
}

#Preview("Empty State") {
    let viewModel = AppViewModel.preview
    viewModel.chores = []
    
    return TodaysChoresCard(
        chores: viewModel.chores,
        onChoreDetailTap: { _ in }
    )
    .padding()
    .environmentObject(viewModel)
}
#endif
