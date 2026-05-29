
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
struct HouseFlowApp: App {
    @StateObject private var appViewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appViewModel)
                .preferredColorScheme(.light)
                .task {
                    // Cold start: attempt silent auto-login
                    await appViewModel.performAutoLogin()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                appViewModel.handleBackground()
            } else if newPhase == .active {
                Task { await appViewModel.handleForeground() }
            }
        }
    }
}
