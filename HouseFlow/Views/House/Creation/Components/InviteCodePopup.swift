import SwiftUI

/// Popup showing the generated invite code after house creation
/// Features: Copy, Share functionality with UIActivityViewController
struct InviteCodePopup: View {
    let inviteCode: String
    let houseName: String
    let onContinue: () -> Void
    @State private var showingShareSheet = false
    @State private var showCopiedFeedback = false
    
    var body: some View {
        ZStack {
            backgroundOverlay
            popupContent
        }
    }
    
    // MARK: - Background
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
    }
    
    // MARK: - Popup Content
    
    private var popupContent: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            headerSection
            inviteCodeSection
            continueButton
        }
        .padding(AppDesign.Spacing.xxl)
        .background(AppDesign.Colors.surface)
        .cornerRadius(AppDesign.CornerRadius.xl)
        .shadow(
            color: AppDesign.Shadow.heavy.color,
            radius: AppDesign.Shadow.heavy.radius,
            x: AppDesign.Shadow.heavy.x,
            y: AppDesign.Shadow.heavy.y
        )
        .padding(.horizontal, AppDesign.Spacing.xxxl)
        .sheet(isPresented: $showingShareSheet) {
            ActivityViewController(
                activityItems: [createShareMessage()],
                applicationActivities: nil
            )
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(AppDesign.Colors.success)
            
            Text("House Created! 🎉")
                .font(AppDesign.Typography.title2)
            
            Text("\(houseName) successfully created")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Invite Code Section
    
    private var inviteCodeSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            Text("Invite Code")
                .font(AppDesign.Typography.headline)
            
            codeDisplayBox
            actionButtonsRow
            
            Text("You can invite your friends to your home by sharing this code")
                .font(AppDesign.Typography.caption)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.Spacing.lg)
        }
    }
    
    private var codeDisplayBox: some View {
        ZStack {
            Text(inviteCode)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundColor(AppDesign.Colors.primary)
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.md)
                .background(AppDesign.Colors.primary.opacity(0.1))
                .cornerRadius(AppDesign.CornerRadius.md)
            
            if showCopiedFeedback {
                Text("Copied!")
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppDesign.Spacing.md)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background(AppDesign.Colors.success)
                    .cornerRadius(AppDesign.CornerRadius.sm)
                    .offset(y: -50)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    private var actionButtonsRow: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            copyButton
            shareButton
        }
    }
    
    private var copyButton: some View {
        Button(action: handleCopy) {
            HStack(spacing: AppDesign.Spacing.xs) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14))
                Text("Copy")
                    .font(AppDesign.Typography.caption)
            }
            .foregroundColor(AppDesign.Colors.primary)
            .padding(.horizontal, AppDesign.Spacing.md)
            .padding(.vertical, AppDesign.Spacing.sm)
            .background(AppDesign.Colors.primary.opacity(0.1))
            .cornerRadius(AppDesign.CornerRadius.sm)
        }
    }
    
    private var shareButton: some View {
        Button(action: { showingShareSheet = true }) {
            HStack(spacing: AppDesign.Spacing.xs) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                Text("Share")
                    .font(AppDesign.Typography.caption)
            }
            .foregroundColor(.white)
            .padding(.horizontal, AppDesign.Spacing.md)
            .padding(.vertical, AppDesign.Spacing.sm)
            .background(AppDesign.Colors.primary)
            .cornerRadius(AppDesign.CornerRadius.sm)
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button(action: onContinue) {
            Text("Enter House")
                .font(AppDesign.Typography.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeight)
                .background(AppDesign.Colors.success)
                .cornerRadius(AppDesign.CornerRadius.md)
        }
    }
    
    // MARK: - Actions
    
    private func handleCopy() {
        UIPasteboard.general.string = inviteCode
        
        withAnimation(AppDesign.Animation.quick) {
            showCopiedFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(AppDesign.Animation.quick) {
                showCopiedFeedback = false
            }
        }
    }
    
    private func createShareMessage() -> String {
        return """
        🏠 \(houseName)'e katılmaya davetlisiniz!
        
        HouseFlow uygulamasını indirin ve aşağıdaki davet kodunu kullanın:
        
        🔑 Davet Kodu: \(inviteCode)
        
        Ev işlerini birlikte organize edelim! 🧹✨
        """
    }
}

// MARK: - Activity View Controller

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Previews

#Preview("Invite Code Popup") {
    InviteCodePopup(
        inviteCode: "ABC123XY",
        houseName: "My Awesome House",
        onContinue: {}
    )
}

#Preview("Dark Mode") {
    InviteCodePopup(
        inviteCode: "XYZ789AB",
        houseName: "Student Apartment",
        onContinue: {}
    )
    .preferredColorScheme(.dark)
}

#Preview("Long House Name") {
    InviteCodePopup(
        inviteCode: "LONG1234",
        houseName: "The Amazing Shared House for University Students",
        onContinue: {}
    )
}
