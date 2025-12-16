import SwiftUI

/// Ana dashboard view - ev görevlerini ve üyelerini gösterir
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct HouseDashboardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedChore: Chore? = nil
    @State private var showChoreDetail = false
    @State private var showNewChore = false
    @State private var buttonState: NewChoreButtonState = .collapsed
    @State private var buttonTimer: Timer?
    @State private var showLogoutConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.Spacing.xxl) {
                headerSection
                
                AnnouncementCard()
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                
                TodaysChoresCard(
                    chores: appViewModel.chores,
                    appViewModel: appViewModel,
                    onChoreDetailTap: { chore in
                        selectedChore = chore
                        showChoreDetail = true
                    }
                )
                .padding(.horizontal, AppDesign.Spacing.xxl)
                
                HouseMembersCard(members: appViewModel.sampleUsers)
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                
                // Spacer for floating button
                Spacer(minLength: 100)
            }
        }
        .overlay(floatingActionButton, alignment: .bottomTrailing)
        .overlay(popupsOverlay)
        .navigationBarHidden(true)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            HStack {
                Text("Hi, \(appViewModel.currentUser?.name ?? "User") 👋")
                    .font(AppDesign.Typography.title2)
                
                Spacer()
                
                Button(action: { showLogoutConfirmation = true }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: AppDesign.Size.iconMedium))
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }
            }
            
            Text("Here's your house today")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppDesign.Spacing.xxl)
        .padding(.top, AppDesign.Spacing.xl)
    }
    
    // MARK: - Floating Action Button
    
    private var floatingActionButton: some View {
        FloatingActionButton(buttonState: $buttonState) {
            handleNewChoreButtonTap()
        }
        .padding(.trailing, AppDesign.Spacing.xxl)
        .padding(.bottom, 30)
    }
    
    // MARK: - Popups Overlay
    
    private var popupsOverlay: some View {
        Group {
            if showChoreDetail, let chore = selectedChore {
                ChoreDetailPopup(
                    chore: chore,
                    appViewModel: appViewModel,
                    onDismiss: {
                        showChoreDetail = false
                        selectedChore = nil
                    }
                )
            }
            
            if showNewChore {
                NewChorePopup(
                    appViewModel: appViewModel,
                    onDismiss: {
                        showNewChore = false
                        resetButtonState()
                    }
                )
            }
            
            if showLogoutConfirmation {
                LogoutConfirmationPopup(
                    onConfirm: {
                        showLogoutConfirmation = false
                        withAnimation(AppDesign.Animation.standard) {
                            appViewModel.logout()
                        }
                    },
                    onCancel: {
                        showLogoutConfirmation = false
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleNewChoreButtonTap() {
        switch buttonState {
        case .collapsed:
            // First tap: expand button with stretch animation
            withAnimation(AppDesign.Animation.spring) {
                buttonState = .expanded
            }
            startButtonTimer()
            
        case .expanded:
            // Second tap: show popup
            buttonTimer?.invalidate()
            showNewChore = true
        }
    }
    
    private func startButtonTimer() {
        buttonTimer?.invalidate()
        buttonTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(AppDesign.Animation.spring) {
                buttonState = .collapsed
            }
        }
    }
    
    private func resetButtonState() {
        buttonTimer?.invalidate()
        withAnimation(AppDesign.Animation.spring) {
            buttonState = .collapsed
        }
    }
}

#Preview {
    HouseDashboardView()
        .environmentObject(AppViewModel())
}
