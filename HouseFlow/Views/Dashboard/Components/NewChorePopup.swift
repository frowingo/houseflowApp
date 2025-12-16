import SwiftUI

/// Yeni görev oluşturma popup component'i
struct NewChorePopup: View {
    let appViewModel: AppViewModel
    let onDismiss: () -> Void
    @State private var choreName = ""
    @State private var choreDescription = ""
    @State private var selectedUser: User? = nil
    @State private var selectedDueLabel = "Today"
    
    let dueLabelOptions = ["Today", "Tomorrow", "This week", "Next week"]
    
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
                formFieldsSection
                actionButtonsSection
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
        .onAppear {
            selectedUser = appViewModel.sampleUsers.first
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: AppDesign.Size.iconLarge))
                    .foregroundColor(AppDesign.Colors.primary)
                
                Text("New Chore")
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
    
    // MARK: - Form Fields Section
    
    private var formFieldsSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            // Chore name
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("Task Name")
                    .font(AppDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                
                TextField("Enter task name", text: $choreName)
                    .font(AppDesign.Typography.body)
                    .padding(.horizontal, AppDesign.Spacing.md)
                    .padding(.vertical, AppDesign.Spacing.md)
                    .background(AppDesign.Colors.secondaryBackground)
                    .cornerRadius(AppDesign.CornerRadius.sm)
            }
            
            // Chore description
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("Description")
                    .font(AppDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                
                TextField("Enter task description", text: $choreDescription, axis: .vertical)
                    .font(AppDesign.Typography.body)
                    .lineLimit(3...5)
                    .padding(.horizontal, AppDesign.Spacing.md)
                    .padding(.vertical, AppDesign.Spacing.md)
                    .background(AppDesign.Colors.secondaryBackground)
                    .cornerRadius(AppDesign.CornerRadius.sm)
            }
            
            // Assign to user
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("Assign To")
                    .font(AppDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppDesign.Spacing.md) {
                        ForEach(appViewModel.sampleUsers, id: \.name) { user in
                            Button(action: {
                                selectedUser = user
                            }) {
                                VStack(spacing: 6) {
                                    UserAvatar(user: user, size: AppDesign.Size.avatarMedium)
                                    Text(user.name)
                                        .font(AppDesign.Typography.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, AppDesign.Spacing.sm)
                                .padding(.vertical, 6)
                                .background(
                                    selectedUser?.name == user.name ?
                                    AppDesign.Colors.primary.opacity(0.2) : Color.clear
                                )
                                .cornerRadius(AppDesign.CornerRadius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                        .stroke(
                                            selectedUser?.name == user.name ?
                                            AppDesign.Colors.primary : Color.clear,
                                            lineWidth: 2
                                        )
                                )
                            }
                            .foregroundColor(AppDesign.Colors.textPrimary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Due date
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("Due")
                    .font(AppDesign.Typography.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                
                HStack(spacing: AppDesign.Spacing.sm) {
                    ForEach(dueLabelOptions, id: \.self) { option in
                        Button(action: {
                            selectedDueLabel = option
                        }) {
                            Text(option)
                                .font(AppDesign.Typography.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, AppDesign.Spacing.md)
                                .padding(.vertical, 6)
                                .background(
                                    selectedDueLabel == option ?
                                    AppDesign.Colors.primary : Color(.systemGray5)
                                )
                                .foregroundColor(
                                    selectedDueLabel == option ? .white : AppDesign.Colors.textPrimary
                                )
                                .cornerRadius(AppDesign.CornerRadius.lg)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Button(action: onDismiss) {
                Text("Cancel")
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(AppDesign.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeight)
                    .background(AppDesign.Colors.primary.opacity(0.1))
                    .cornerRadius(AppDesign.CornerRadius.md)
            }
            
            Button(action: createChore) {
                Text("Create Chore")
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeight)
                    .background(canCreateChore ? AppDesign.Colors.primary : Color.gray)
                    .cornerRadius(AppDesign.CornerRadius.md)
            }
            .disabled(!canCreateChore)
        }
    }
    
    // MARK: - Helper Properties & Methods
    
    private var canCreateChore: Bool {
        !choreName.isEmpty && selectedUser != nil
    }
    
    private func createChore() {
        guard let user = selectedUser, !choreName.isEmpty else { return }
        
        let newChore = Chore(
            title: choreName,
            description: choreDescription,
            assignedTo: user,
            dueLabel: selectedDueLabel
        )
        
        // Demo: Just add to current chores list
        appViewModel.chores.append(newChore)
        
        onDismiss()
    }
}

#Preview {
    NewChorePopup(
        appViewModel: AppViewModel(),
        onDismiss: {}
    )
}
