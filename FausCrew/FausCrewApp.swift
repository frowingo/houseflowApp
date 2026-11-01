
import SwiftUI

// MARK: - Keyboard Dismiss Extension
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            hideKeyboard()
        }
    }
}

@main
struct FausCrewApp: App {
    @UIApplicationDelegateAdaptor(FausCrewAppDelegate.self) private var appDelegate
    @StateObject private var appViewModel = AppViewModel()
    @StateObject private var themeStore = ThemeStore()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSplash = true
    /// Until the splash starts opening, the app underneath is fully hidden and holds its animations.
    @State private var splashCovering = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environmentObject(appViewModel)
                    .environmentObject(appViewModel.router)
                    .environmentObject(themeStore)
                    .environment(\.fausSplashActive, splashCovering)
                    .task {
                        appViewModel.prepareLocalization()
                        // Cold start: attempt silent auto-login while the splash plays.
                        await appViewModel.performAutoLogin()
                    }

                if showsSplash {
                    FausSplashView(onReveal: { splashCovering = false }) { showsSplash = false }
                        .zIndex(1)
                }
            }
            .environment(\.fausSelectedTheme, themeStore.theme)
            .preferredColorScheme(themeStore.theme.colorScheme)
            // Google, Facebook and Snapchat return to the app through these redirects.
            .onOpenURL { SocialURLHandler.handle($0) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                appViewModel.handleBackground()
            } else if newPhase == .active {
                themeStore.syncAppIcon()
                Task { await appViewModel.handleForeground() }
            }
        }
    }
}
