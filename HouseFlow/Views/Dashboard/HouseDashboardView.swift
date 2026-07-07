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
    @State private var appeared = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppDesign.Spacing.lg) {
                    headerSection

                    AnnouncementCard()
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.12), value: appeared)
                    
                    TodaysChoresCard(
                        chores: appViewModel.dashboardChores,
                        onChoreDetailTap: { chore in
                            selectedChore = chore
                            showChoreDetail = true
                        }
                    )
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 26)
                    .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.22), value: appeared)
                    
                    HouseMembersCard(members: appViewModel.dashboardMembers)
                        .padding(.horizontal, AppDesign.Spacing.xxl)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 26)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.32), value: appeared)
                    
                    // Spacer for floating button + tab bar clearance
                    Spacer(minLength: 140)
                }
            }
            .overlay(floatingActionButton, alignment: .bottomTrailing)
            .overlay(popupsOverlay)
        }
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
        .onDisappear {
            stopButtonTimer()
        }
    }
    
    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .leading) {
            // Orange gradient banner
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 0.85, brightness: 0.95),
                            Color(hue: 0.05, saturation: 0.75, brightness: 0.80),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 100)

            // Decorative circles
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .offset(x: 100, y: -40)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 120, height: 120)
                .offset(x: 200, y: 55)

            // Text + logout button
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                    Text(appViewModel.localized(
                        "dashboard_greeting_template",
                        replacements: [
                            "first_name": appViewModel.currentUser?.firstName
                                ?? appViewModel.localized("common_user_fallback")
                        ]
                    ))
                        .font(AppDesign.Typography.title2)
                        .foregroundStyle(.white)
                    Text(appViewModel.currentHouseDetails?.name ?? appViewModel.houseName)
                        .font(AppDesign.Typography.subheadline)
                        .foregroundStyle(Color.white.opacity(0.82))
                }

                Spacer()

                Button(action: { showLogoutConfirmation = true }) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: AppDesign.Size.iconMedium))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(10)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, AppDesign.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .shadow(color: Color.orange.opacity(0.35), radius: 16, x: 0, y: 6)
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.top, AppDesign.Spacing.xs)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }
    
    // MARK: - Floating Action Button
    
    private var floatingActionButton: some View {
        FloatingActionButton(buttonState: $buttonState) {
            handleNewChoreButtonTap()
        }
        .padding(.trailing, AppDesign.Spacing.xxl)
        .padding(.bottom, 110)
    }
    
    // MARK: - Popups Overlay
    
    private var popupsOverlay: some View {
        Group {
            if showChoreDetail, let chore = selectedChore {
                ChoreDetailPopup(
                    chore: chore,
                    appViewModel: appViewModel,
                    onDismiss: {
                        dismissChoreDetail()
                    }
                )
            }

            if showNewChore {
                NewChorePopup(
                    appViewModel: appViewModel,
                    onDismiss: {
                        dismissNewChore()
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
                        dismissLogoutConfirmation()
                    }
                )
            }
        }
        .onChange(of: showChoreDetail) { _, _ in syncOverlayPresentation() }
        .onChange(of: showNewChore) { _, _ in syncOverlayPresentation() }
        .onChange(of: showLogoutConfirmation) { _, _ in syncOverlayPresentation() }
    }

    private func syncOverlayPresentation() {
        appViewModel.isOverlayPresented = showChoreDetail || showNewChore || showLogoutConfirmation
    }

    private func dismissChoreDetail() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showChoreDetail = false
                selectedChore = nil
            }
        }
    }

    private func dismissNewChore() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showNewChore = false
            }
            resetButtonState()
        }
    }

    private func dismissLogoutConfirmation() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showLogoutConfirmation = false
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
        stopButtonTimer()
        buttonTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(AppDesign.Animation.spring) {
                buttonState = .collapsed
            }
            buttonTimer = nil
        }
    }
    
    private func resetButtonState() {
        stopButtonTimer()
        withAnimation(AppDesign.Animation.spring) {
            buttonState = .collapsed
        }
    }

    private func stopButtonTimer() {
        buttonTimer?.invalidate()
        buttonTimer = nil
    }
}

#Preview {
    HouseDashboardView()
        .environmentObject(AppViewModel())
}
