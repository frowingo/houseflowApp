import SwiftUI

/// House selection screen - Choose between creating or joining a house
/// Refactored: Component'e bölündü, Design System kullanıyor
struct HouseSelectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            headerSection
            optionsSection
            Spacer(minLength: 60)
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Text("Your House")
                .font(AppDesign.Typography.largeTitle)
            
            Text("Create a new house or join an existing one")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.bottom, AppDesign.Spacing.xxxl)
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(spacing: AppDesign.Spacing.xl) {
            createHouseButton
            joinHouseButton
        }
        .padding(.horizontal, AppDesign.Spacing.xxl)
    }
    
    private var createHouseButton: some View {
        Button(action: {
            withAnimation(AppDesign.Animation.standard) {
                appViewModel.showCreateHouseScreen()
            }
        }) {
            HouseOptionCard(
                title: "Create New House",
                subtitle: "Start fresh with your roommates",
                iconName: "plus.circle.fill",
                backgroundColor: .blue
            )
        }
        .buttonStyle(CardButtonStyle())
    }
    
    private var joinHouseButton: some View {
        Button(action: {
            withAnimation(AppDesign.Animation.standard) {
                appViewModel.showJoinHouseScreen()
            }
        }) {
            HouseOptionCard(
                title: "Join Existing House",
                subtitle: "Enter an invite code to join",
                iconName: "person.2.circle.fill",
                backgroundColor: .green
            )
        }
        .buttonStyle(CardButtonStyle())
    }
}

// MARK: - Card Button Style

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(AppDesign.Animation.quick, value: configuration.isPressed)
    }
}

#Preview {
    HouseSelectionView()
        .environmentObject(AppViewModel())
}
