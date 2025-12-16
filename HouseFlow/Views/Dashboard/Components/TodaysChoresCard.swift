import SwiftUI

/// Bugünün görevlerini listeleyen kart component'i
struct TodaysChoresCard: View {
    let chores: [Chore]
    let appViewModel: AppViewModel
    let onChoreDetailTap: (Chore) -> Void
    
    var todaysChores: [Chore] {
        chores.filter { $0.dueLabel == "Today" || $0.dueLabel == "Overdue" }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Text("Today's Chores")
                .font(AppDesign.Typography.headline)
            
            if todaysChores.isEmpty {
                emptyStateView
            } else {
                VStack(spacing: AppDesign.Spacing.md) {
                    ForEach(todaysChores) { chore in
                        ChoreRow(
                            chore: chore,
                            onDetailTap: {
                                onChoreDetailTap(chore)
                            }
                        )
                    }
                }
            }
        }
        .padding(AppDesign.Spacing.xl)
        .background(AppDesign.Colors.cardBackground)
        .cornerRadius(AppDesign.CornerRadius.lg)
        .shadow(
            color: AppDesign.Shadow.light.color,
            radius: AppDesign.Shadow.light.radius,
            x: AppDesign.Shadow.light.x,
            y: AppDesign.Shadow.light.y
        )
    }
    
    private var emptyStateView: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40))
                .foregroundColor(AppDesign.Colors.success)
            
            Text("All caught up!")
                .font(AppDesign.Typography.headline)
            
            Text("No chores due today")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.xxl)
    }
}

#Preview("With Chores") {
    let viewModel = AppViewModel()
    viewModel.chores = [
        Chore(title: "Clean kitchen", description: "Wipe surfaces", assignedTo: User(name: "John", points: 10), dueLabel: "Today"),
        Chore(title: "Take out trash", description: "Empty bins", assignedTo: User(name: "Jane", points: 8), dueLabel: "Today"),
        Chore(title: "Vacuum", description: "Living room", assignedTo: User(name: "Bob", points: 12), dueLabel: "Overdue")
    ]
    
    return TodaysChoresCard(
        chores: viewModel.chores,
        appViewModel: viewModel,
        onChoreDetailTap: { _ in }
    )
    .padding()
    .environmentObject(viewModel)
}

#Preview("Empty State") {
    let viewModel = AppViewModel()
    viewModel.chores = []
    
    return TodaysChoresCard(
        chores: viewModel.chores,
        appViewModel: viewModel,
        onChoreDetailTap: { _ in }
    )
    .padding()
    .environmentObject(viewModel)
}
