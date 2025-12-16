import SwiftUI

/// Çıkış onay popup component'i
struct LogoutConfirmationPopup: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Popup content
            VStack(spacing: AppDesign.Spacing.xxl) {
                // Header
                VStack(spacing: AppDesign.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(AppDesign.Colors.warning)
                    
                    Text("Confirm Logout")
                        .font(AppDesign.Typography.title2)
                    
                    Text("Are you sure you want to logout? You will need to sign in again to access your house.")
                        .font(AppDesign.Typography.subheadline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppDesign.Spacing.lg)
                }
                
                // Buttons
                VStack(spacing: AppDesign.Spacing.md) {
                    Button(action: onConfirm) {
                        Text("Yes, Logout")
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppDesign.Colors.error)
                            .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(AppDesign.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppDesign.Colors.primary.opacity(0.1))
                            .cornerRadius(AppDesign.CornerRadius.md)
                    }
                }
            }
            .padding(AppDesign.Spacing.xxl)
            .background(AppDesign.Colors.background)
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(
                color: AppDesign.Shadow.heavy.color,
                radius: AppDesign.Shadow.heavy.radius,
                x: AppDesign.Shadow.heavy.x,
                y: AppDesign.Shadow.heavy.y
            )
            .padding(.horizontal, 60)
        }
    }
}

#Preview {
    LogoutConfirmationPopup(
        onConfirm: {},
        onCancel: {}
    )
}
