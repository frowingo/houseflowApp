import SwiftUI

/// Tek bir görev satırını gösteren component
struct ChoreRow: View {
    let chore: Chore
    let onDetailTap: () -> Void
    
    var body: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            // Status icon - fixed width column
            Image(systemName: choreStatus.iconName)
                .font(.system(size: AppDesign.Size.iconMedium))
                .foregroundColor(choreStatus.color)
                .frame(width: 24)
            
            // Task title - flexible column
            Text(chore.title)
                .font(AppDesign.Typography.bodyBold)
                .strikethrough(chore.isDone)
                .foregroundColor(chore.isDone ? AppDesign.Colors.textSecondary : AppDesign.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // User avatar - fixed width column
            UserAvatar(user: chore.assignedTo, size: AppDesign.Size.avatarSmall)
                .frame(width: AppDesign.Size.avatarSmall)
            
            // Status badge - fixed width column
            Text(choreStatus.displayName)
                .font(AppDesign.Typography.caption)
                .fontWeight(.medium)
                .padding(.horizontal, AppDesign.Spacing.sm)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(choreStatus.color.opacity(0.15))
                .foregroundColor(choreStatus.color)
                .cornerRadius(AppDesign.CornerRadius.sm)
                .frame(width: 80)
            
            // Detail button - fixed width column
            Button(action: onDetailTap) {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundColor(AppDesign.Colors.primary)
            }
            .frame(width: 24)
        }
        .padding(.vertical, AppDesign.Spacing.sm)
        .padding(.horizontal, AppDesign.Spacing.xs)
    }
    
    private var choreStatus: ChoreStatus {
        ChoreStatus(rawValue: chore.status) ?? .draft
    }
}

#Preview("Pending Chore") {
    ChoreRow(
        chore: Chore(
            title: "Clean kitchen",
            description: "Clean all surfaces",
            assignedTo: User(name: "John Doe", points: 10),
            dueLabel: "Today",
            isDone: false
        ),
        onDetailTap: {}
    )
    .padding()
}

#Preview("Done Chore") {
    ChoreRow(
        chore: Chore(
            title: "Take out trash",
            description: "Empty all bins",
            assignedTo: User(name: "Jane Smith", points: 15),
            dueLabel: "Today",
            isDone: true
        ),
        onDetailTap: {}
    )
    .padding()
}

#Preview("Overdue Chore") {
    ChoreRow(
        chore: Chore(
            title: "Vacuum living room",
            description: "Vacuum thoroughly",
            assignedTo: User(name: "Bob Wilson", points: 8),
            dueLabel: "Overdue",
            isDone: false
        ),
        onDetailTap: {}
    )
    .padding()
}
