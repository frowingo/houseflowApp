import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var currentPage = 0
    
    let onboardingPages = [
        OnboardingPage(
            titleKey: "onboarding_page_1_title",
            subtitleKey: "onboarding_page_1_subtitle",
            imageName: "house.fill"
        ),
        OnboardingPage(
            titleKey: "onboarding_page_2_title",
            subtitleKey: "onboarding_page_2_subtitle",
            imageName: "person.2.fill"
        ),
        OnboardingPage(
            titleKey: "onboarding_page_3_title",
            subtitleKey: "onboarding_page_3_subtitle",
            imageName: "bell.badge.fill"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // App Header
            VStack(spacing: 8) {
                Text(appViewModel.localized("app_name"))
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text(appViewModel.localized("onboarding_app_subtitle"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            .padding(.bottom, 40)
            
            // Onboarding Pages - Centered
            Spacer()
            
            VStack(spacing: 30) {
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        VStack(spacing: 30) {
                            Image(systemName: onboardingPages[index].imageName)
                                .font(.system(size: 80))
                                .foregroundColor(.blue)
                            
                            VStack(spacing: 16) {
                                Text(appViewModel.localized(onboardingPages[index].titleKey))
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                                
                                Text(appViewModel.localized(onboardingPages[index].subtitleKey))
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 20)
                        .background(Color.gray.opacity(0.08))
                        .cornerRadius(20)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 320)
                .padding(.horizontal, 20)
                
                // Custom Page Indicator
                HStack(spacing: 12) {
                    ForEach(0..<onboardingPages.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: currentPage == index ? 24 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
            }
            
            Spacer()
            
            // Get Started Button - Only active on last page
            Button(action: {
                if currentPage == onboardingPages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        appViewModel.completeOnboarding()
                    }
                }
            }) {
                Text(appViewModel.localized("onboarding_get_started_button"))
                    .font(.headline)
                    .foregroundColor(isButtonActive ? .white : .gray)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(isButtonActive ? Color.blue : Color.gray.opacity(0.3))
                    .cornerRadius(16)
                    .scaleEffect(isButtonActive ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: isButtonActive)
            }
            .disabled(!isButtonActive)
            .padding(.horizontal, 24)
            .padding(.bottom, 50)
        }
    }
    
    private var isButtonActive: Bool {
        currentPage == onboardingPages.count - 1
    }
}

struct OnboardingPage {
    let titleKey: String
    let subtitleKey: String
    let imageName: String
}

#Preview {
    OnboardingView()
        .environmentObject(AppViewModel())
}
