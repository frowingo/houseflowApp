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
        .background(selectionBackground)
        .navigationBarHidden(true)
    }

    private var selectionBackground: some View {
        MainScreenBackground()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Text(appViewModel.localized("house_selection_title"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(AppDesign.Colors.textPrimary)
            
            Text(appViewModel.localized("house_selection_subtitle"))
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
        .padding(.bottom, AppDesign.Spacing.xxxl)
        .overlay(alignment: .bottom) {
            Capsule()
                .fill(HouseJourneyTheme.accentOrange)
                .frame(width: 34, height: 4)
        }
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
                title: appViewModel.localized("house_selection_create_title"),
                subtitle: appViewModel.localized("house_selection_create_subtitle"),
                iconName: "plus.circle.fill",
                backgroundColor: HouseJourneyTheme.indigo
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
                title: appViewModel.localized("house_selection_join_title"),
                subtitle: appViewModel.localized("house_selection_join_subtitle"),
                iconName: "person.2.circle.fill",
                backgroundColor: HouseJourneyTheme.teal
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
