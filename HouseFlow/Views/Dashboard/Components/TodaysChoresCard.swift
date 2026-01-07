import SwiftUI

/// 🎨 Ultra-Modern Today's Chores Card with Interactive Animations
/// Features: Swipe gestures, 3D transforms, particle effects, progress tracking
struct TodaysChoresCard: View {
    let chores: [Chore]
    let appViewModel: AppViewModel
    let onChoreDetailTap: (Chore) -> Void
    
    @State private var selectedChoreId: UUID? = nil
    @State private var choreOffsets: [UUID: CGFloat] = [:]
    @State private var isExpanded = false
    @State private var particleAnimations: [UUID: Bool] = [:]
    @State private var pulseAnimation = false
    @State private var iconPressed = false
    
    var todaysChores: [Chore] {
        chores.filter { $0.dueLabel == "Today" || $0.dueLabel == "Overdue" }
    }
    
    var completedCount: Int {
        todaysChores.filter { $0.isDone }.count
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
                    Text("Today's Tasks")
                        .font(AppDesign.Typography.headline)
                        .foregroundColor(AppDesign.Colors.textPrimary)
                    
                    if totalCount > 0 {
                        Text("\(completedCount) of \(totalCount) completed")
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
                    isSelected: selectedChoreId == chore.id,
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
                Text("All Done! 🎉")
                    .font(AppDesign.Typography.title3)
                    .foregroundColor(AppDesign.Colors.textPrimary)
                
                Text("You've completed all tasks for today")
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
            Text("\(Int(progress * 100))%")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppDesign.Colors.primary)
        }
    }
}

// MARK: - Modern Chore Row with 3D Drag

struct ModernChoreRow: View {
    let chore: Chore
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            // Status indicator with pulse
            ZStack {
                if !chore.isDone {
                    Circle()
                        .fill(dueColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                }
                
                Image(systemName: chore.isDone ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: chore.isDone ? 
                                [AppDesign.Colors.success, AppDesign.Colors.secondary] :
                                [dueColor, dueColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(chore.isDone ? 0 : -15))
            }
            .frame(width: 32)
            
            // Task details
            VStack(alignment: .leading, spacing: 4) {
                Text(chore.title)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundColor(chore.isDone ? AppDesign.Colors.textSecondary : AppDesign.Colors.textPrimary)
                    .strikethrough(chore.isDone)
                
                HStack(spacing: AppDesign.Spacing.sm) {
                    UserAvatar(user: chore.assignedTo, size: 20)
                    
                    Text(chore.assignedTo.name)
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                    
                    Spacer()
                    
                    // Priority badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(dueColor)
                            .frame(width: 6, height: 6)
                        
                        Text(chore.dueLabel)
                            .font(AppDesign.Typography.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(dueColor.opacity(0.15))
                    .cornerRadius(AppDesign.CornerRadius.sm)
                }
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .fill(AppDesign.Colors.background)
                .shadow(
                    color: Color.black.opacity(isDragging ? 0.15 : 0.08),
                    radius: isDragging ? 12 : 8,
                    x: dragOffset.width * 0.1,
                    y: 2 + dragOffset.height * 0.05
                )
        )
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .offset(x: dragOffset.width * 0.3, y: dragOffset.height * 0.15)
        .rotation3DEffect(
            .degrees(Double(dragOffset.width) * 0.05),
            axis: (x: 0, y: 1, z: 0)
        )
        .rotation3DEffect(
            .degrees(Double(dragOffset.height) * -0.05),
            axis: (x: 1, y: 0, z: 0)
        )
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    // Limit drag distance for subtle effect
                    let maxDrag: CGFloat = 40
                    dragOffset.width = min(max(value.translation.width, -maxDrag), maxDrag)
                    dragOffset.height = min(max(value.translation.height, -maxDrag * 0.5), maxDrag * 0.5)
                }
                .onEnded { value in
                    // If minimal movement, treat as tap
                    if abs(value.translation.width) < 5 && abs(value.translation.height) < 5 {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        onTap()
                    }
                    
                    // Spring back to original position
                    withAnimation(AppDesign.Animation.spring) {
                        dragOffset = .zero
                        isDragging = false
                    }
                }
        )
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
