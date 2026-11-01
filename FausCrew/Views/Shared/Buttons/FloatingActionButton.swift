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

    @Environment(\.fausTheme) private var theme
    
    var body: some View {
        Button(action: action) {
            Group {
                if buttonState == .collapsed {
                    Image(systemName: "plus")
                        .font(.system(size: AppDesign.Size.iconMedium, weight: .semibold))
                        .foregroundColor(AppDesign.Colors.onAccent)
                        .frame(width: AppDesign.Size.fabSize, height: AppDesign.Size.fabSize)
                        .background(fabGradient)
                        .clipShape(Circle())
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "plus")
                            .font(.system(size: AppDesign.Size.iconSmall + 2, weight: .semibold))
                        LocalizedText("floating_new_chore_button")
                            .font(AppDesign.Typography.headline)
                            .transition(.scale.combined(with: .opacity))
                    }
                    .foregroundColor(AppDesign.Colors.onAccent)
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.lg)
                    .background(fabGradient)
                    .cornerRadius(28)
                }
            }
            .scaleEffect(buttonState == .expanded ? 1.05 : 1.0)
            .shadow(
                color: theme.decor.fabShadow,
                radius: 8,
                x: 0,
                y: 4
            )
        }
    }
    
    private var fabGradient: LinearGradient {
        LinearGradient(
            colors: theme.decor.fabColors,
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
