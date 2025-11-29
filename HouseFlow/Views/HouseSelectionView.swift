import SwiftUI

struct HouseSelectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Text("Your House")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Create a new house or join an existing one")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // House Options
            VStack(spacing: 20) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
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
                .scaleEffect(0.98)
                .animation(.easeInOut(duration: 0.1), value: false)
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
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
                .scaleEffect(0.98)
                .animation(.easeInOut(duration: 0.1), value: false)
            }
            .padding(.horizontal, 24)
            
            Spacer(minLength: 60)
        }
        .navigationBarHidden(true)
    }
}

struct HouseOptionCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .background(backgroundColor)
                .clipShape(Circle())
                .shadow(color: backgroundColor.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Content
            VStack(spacing: 10) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(Color(.systemBackground))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

#Preview {
    HouseSelectionView()
        .environmentObject(AppViewModel())
}