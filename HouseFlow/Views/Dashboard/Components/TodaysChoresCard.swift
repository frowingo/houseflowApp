import SwiftUI

/// 🎨 Ultra-Modern Today's Chores Card with Interactive Animations
/// Features: Swipe gestures, 3D transforms, particle effects, progress tracking
struct TodaysChoresCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let chores: [Chore]
    let onChoreDetailTap: (Chore) -> Void
    
    @State private var pulseAnimation = false
    @State private var iconPressed = false
    
    var todaysChores: [Chore] {
        chores
    }
    
    var completedCount: Int {
        todaysChores.filter { $0.status == ChoreStatus.completed.rawValue }.count
    }
    
    var totalCount: Int {
        todaysChores.count
    }
    
    var progressPercentage: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient Header with Stats
            headerSection
            
            Divider()
                .padding(.horizontal, AppDesign.Spacing.xl)
            
            // Chores Content
            if todaysChores.isEmpty {
                emptyStateView
            } else {
                choresListView
            }
        }
        .background(
            ZStack {
                // Glassmorphism base
                AppDesign.Colors.cardBackground

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
        .onAppear {
            // Removed auto-pulse animation
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            HStack {
                // Animated Icon - Only pulses when pressed
                Button(action: {
                    iconPressed = true
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        iconPressed = false
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppDesign.Colors.primary, AppDesign.Colors.secondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .scaleEffect(iconPressed ? 1.1 : 1.0)
                            .opacity(iconPressed ? 0.6 : 1.0)
                        
                        Image(systemName: "list.clipboard.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .animation(AppDesign.Animation.spring.repeatForever(autoreverses: true), value: iconPressed)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(appViewModel.localized("todays_tasks_title"))
                        .font(AppDesign.Typography.headline)
                        .foregroundColor(AppDesign.Colors.textPrimary)
                    
                    if totalCount > 0 {
                        Text(appViewModel.localized(
                            "todays_tasks_completed_template",
                            replacements: [
                                "completed": "\(completedCount)",
                                "total": "\(totalCount)"
                            ]
                        ))
                            .font(AppDesign.Typography.caption)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                    }
                }
                
                Spacer()
                
                // Circular Progress Ring
                if totalCount > 0 {
                    CircularProgressView(progress: progressPercentage)
                        .frame(width: 50, height: 50)
                }
            }
            
            // Progress Bar
            if totalCount > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm)
                            .fill(AppDesign.Colors.textSecondary.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm)
                            .fill(
                                LinearGradient(
                                    colors: [AppDesign.Colors.primary, AppDesign.Colors.secondary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progressPercentage, height: 6)
                            .animation(AppDesign.Animation.spring, value: progressPercentage)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(AppDesign.Spacing.xl)
    }
    
    // MARK: - Chores List
    
    private var choresListView: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ForEach(todaysChores) { chore in
                ModernChoreRow(
                    chore: chore,
                    onTap: {
                        onChoreDetailTap(chore)
                    }
                )
            }
        }
        .padding(AppDesign.Spacing.xl)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            ZStack {
                // Gradient background circles
                Circle()
                    .fill(AppDesign.Colors.success.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .blur(radius: 20)
                
                Circle()
                    .fill(AppDesign.Colors.secondary.opacity(0.3))
                    .frame(width: 90, height: 90)
                    .scaleEffect(pulseAnimation ? 1.0 : 1.2)
                    .blur(radius: 15)
                
                // Main icon
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppDesign.Colors.success, AppDesign.Colors.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(pulseAnimation ? 5 : -5))
            }
            .animation(AppDesign.Animation.spring.repeatForever(autoreverses: true), value: pulseAnimation)
            
            VStack(spacing: AppDesign.Spacing.sm) {
                Text(appViewModel.localized("todays_tasks_empty_title"))
                    .font(AppDesign.Typography.title3)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                
                Text(appViewModel.localized("todays_tasks_empty_subtitle"))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.huge)
    }
    
    // MARK: - Helper Methods
    // Removed helper methods as they're no longer needed
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(AppDesign.Colors.textSecondary.opacity(0.2), lineWidth: 4)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [AppDesign.Colors.primary, AppDesign.Colors.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(AppDesign.Animation.spring, value: progress)
            
            // Percentage text
            LocalizedText(
                "progress_percent_template",
                replacements: ["percent": "\(Int(progress * 100))"]
            )
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppDesign.Colors.primary)
        }
    }
}

// MARK: - Modern Chore Row

struct ModernChoreRow: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let chore: Chore
    let onTap: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onTap()
        } label: {
            HStack(spacing: AppDesign.Spacing.lg) {
                // Status indicator with pulse
                let choreStatus = ChoreStatus(rawValue: chore.status) ?? .draft
                let isCompleted = choreStatus == .completed
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
                    Text(chore.title)
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundColor(isCompleted ? AppDesign.Colors.textSecondary : AppDesign.Colors.textPrimary)
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
                            Text(appViewModel.localized(choreStatus.localizationKey))
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
        ChoreStatus(rawValue: chore.status) ?? .draft
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

// MARK: - Previews

#Preview("With Chores") {
    let viewModel = AppViewModel()
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
    let viewModel = AppViewModel()
    viewModel.chores = []
    
    return TodaysChoresCard(
        chores: viewModel.chores,
        onChoreDetailTap: { _ in }
    )
    .padding()
    .environmentObject(viewModel)
}
