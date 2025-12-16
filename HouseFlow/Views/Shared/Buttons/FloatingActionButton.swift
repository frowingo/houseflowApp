import SwiftUI

/// Floating action button state'leri
enum NewChoreButtonState {
    case collapsed      // + icon, circle shape
    case expanded       // "New Chore" text, rounded rectangle
}

/// Yeni görev eklemek için floating action button
struct FloatingActionButton: View {
    @Binding var buttonState: NewChoreButtonState
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Group {
                if buttonState == .collapsed {
                    Image(systemName: "plus")
                        .font(.system(size: AppDesign.Size.iconMedium, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: AppDesign.Size.fabSize, height: AppDesign.Size.fabSize)
                        .background(fabGradient)
                        .clipShape(Circle())
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: AppDesign.Size.iconSmall + 2, weight: .semibold))
                        Text("New Chore")
                            .font(AppDesign.Typography.headline)
                            .transition(.scale.combined(with: .opacity))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.lg)
                    .background(fabGradient)
                    .cornerRadius(28)
                }
            }
            .scaleEffect(buttonState == .expanded ? 1.05 : 1.0)
            .shadow(
                color: AppDesign.Colors.secondary.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
    
    private var fabGradient: LinearGradient {
        LinearGradient(
            colors: [AppDesign.Colors.secondary, AppDesign.Colors.secondary.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview("Collapsed") {
    @Previewable @State var state: NewChoreButtonState = .collapsed
    FloatingActionButton(buttonState: $state) {
        state = .expanded
    }
}

#Preview("Expanded") {
    @Previewable @State var state: NewChoreButtonState = .expanded
    FloatingActionButton(buttonState: $state) {
        state = .collapsed
    }
}
