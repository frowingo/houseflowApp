import SwiftUI

/// Tek bir görev satırını gösteren component
struct ChoreRow: View {
    let chore: Chore
    let onDetailTap: () -> Void
    
    var body: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            // Status icon - fixed width column
            Image(systemName: chore.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: AppDesign.Size.iconMedium))
                .foregroundColor(chore.isDone ? AppDesign.Colors.success : AppDesign.Colors.textSecondary)
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
            Text(chore.isDone ? "Done" : "Pending")
                .font(AppDesign.Typography.caption)
                .fontWeight(.medium)
                .padding(.horizontal, AppDesign.Spacing.sm)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(chore.isDone ? AppDesign.Colors.success.opacity(0.2) : dueColor.opacity(0.2))
                .foregroundColor(chore.isDone ? AppDesign.Colors.success : dueColor)
                .cornerRadius(AppDesign.CornerRadius.sm)
                .frame(width: 70)
            
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
    
    private var dueColor: Color {
        switch chore.dueLabel {
        case "Overdue":
            return AppDesign.Colors.error
        case "Today":
            return AppDesign.Colors.warning
        default:
            return AppDesign.Colors.primary
        }
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
