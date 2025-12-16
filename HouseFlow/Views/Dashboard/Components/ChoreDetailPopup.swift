import SwiftUI

/// Görev detaylarını gösteren popup component'i
struct ChoreDetailPopup: View {
    let chore: Chore
    let appViewModel: AppViewModel
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Popup content
            VStack(spacing: AppDesign.Spacing.xxl) {
                headerSection
                choreInfoSection
                statusControlSection
            }
            .padding(AppDesign.Spacing.xxl)
            .background(AppDesign.Colors.background)
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(
                color: AppDesign.Shadow.heavy.color,
                radius: AppDesign.Shadow.heavy.radius,
                x: AppDesign.Shadow.heavy.x,
                y: AppDesign.Shadow.heavy.y
            )
            .padding(.horizontal, AppDesign.Spacing.huge)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: AppDesign.Size.iconLarge))
                    .foregroundColor(AppDesign.Colors.primary)
                
                Text("Chore Details")
                    .font(AppDesign.Typography.title2)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: AppDesign.Size.iconLarge))
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }
            }
            
            Divider()
        }
    }
    
    // MARK: - Chore Info Section
    
    private var choreInfoSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            // Task title and description
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Text("Task")
                        .font(AppDesign.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                    
                    Text(chore.title)
                        .font(AppDesign.Typography.title3)
                }
                
                if !chore.description.isEmpty {
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                        Text("Description")
                            .font(AppDesign.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                        
                        Text(chore.description)
                            .font(AppDesign.Typography.body)
                            .foregroundColor(AppDesign.Colors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Assigned person
            HStack {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Text("Assigned to")
                        .font(AppDesign.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                    
                    HStack(spacing: AppDesign.Spacing.md) {
                        UserAvatar(user: chore.assignedTo, size: AppDesign.Size.avatarMedium)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chore.assignedTo.name)
                                .font(AppDesign.Typography.headline)
                            
                            Text("\(chore.assignedTo.points) points")
                                .font(AppDesign.Typography.caption)
                                .foregroundColor(AppDesign.Colors.textSecondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            // Due date
            HStack {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Text("Due")
                        .font(AppDesign.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                    
                    Text(chore.dueLabel)
                        .font(AppDesign.Typography.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal, AppDesign.Spacing.md)
                        .padding(.vertical, 6)
                        .background(dueColor.opacity(0.2))
                        .foregroundColor(dueColor)
                        .cornerRadius(AppDesign.CornerRadius.sm)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Status Control Section
    
    private var statusControlSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            Text("Status")
                .font(AppDesign.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: AppDesign.Spacing.md) {
                // Mark as Done button
                Button(action: {
                    if !chore.isDone {
                        appViewModel.toggleChoreCompletion(chore.id)
                    }
                    onDismiss()
                }) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: AppDesign.Size.iconSmall))
                        Text("Mark as Done")
                            .font(AppDesign.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(chore.isDone ? AppDesign.Colors.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightSmall)
                    .background(chore.isDone ? Color.gray.opacity(0.2) : AppDesign.Colors.success)
                    .cornerRadius(AppDesign.CornerRadius.md)
                }
                .disabled(chore.isDone)
                
                // Mark as Pending button
                Button(action: {
                    if chore.isDone {
                        appViewModel.toggleChoreCompletion(chore.id)
                    }
                    onDismiss()
                }) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "clock.circle.fill")
                            .font(.system(size: AppDesign.Size.iconSmall))
                        Text("Mark as Pending")
                            .font(AppDesign.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(!chore.isDone ? AppDesign.Colors.textSecondary : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightSmall)
                    .background(!chore.isDone ? Color.gray.opacity(0.2) : AppDesign.Colors.warning)
                    .cornerRadius(AppDesign.CornerRadius.md)
                }
                .disabled(!chore.isDone)
            }
        }
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

#Preview {
    ChoreDetailPopup(
        chore: Chore(
            title: "Clean kitchen",
            description: "Wipe down all surfaces and organize items",
            assignedTo: User(name: "John Doe", points: 12),
            dueLabel: "Today",
            isDone: false
        ),
        appViewModel: AppViewModel(),
        onDismiss: {}
    )
}
