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
    
    /// Brand header card: orange → berry with the white F badge.
    private var headerSection: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 70, height: 70)
                Circle()
                    .fill(Color.white)
                    .frame(width: 58, height: 58)
                    .shadow(color: FausBrand.deepBerry.opacity(0.3), radius: 8, x: 0, y: 6)
                Rectangle()
                    .fill(FausBrand.markGradient)
                    .frame(width: 58, height: 58)
                    .mask(FausMark(size: 58))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("house_selection_title"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(appViewModel.localized("house_selection_subtitle"))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(.white.opacity(0.82))
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(FausHeroBackground())
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous))
        .shadow(color: FausBrand.deepBerry.opacity(0.28), radius: 18, x: 0, y: 8)
        .padding(.horizontal, AppDesign.Spacing.xxl)
        .padding(.top, 60)
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
                kind: .create
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
                kind: .join
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
