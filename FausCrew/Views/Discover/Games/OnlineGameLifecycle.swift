import SwiftUI
import FausCrewCore

/// What every online game screen does when the account or house changes under it, the
/// session ends, or it goes away: tell the model, stop the game and turn the screen back to portrait.
private struct OnlineGameLifecycle: ViewModifier {
    @EnvironmentObject private var appViewModel: AppViewModel
    let requiresSignIn: Bool
    let identityChanged: (_ houseID: String?, _ userID: String?) -> Void
    let stop: () -> Void
    let beforeStopOnDisappear: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: appViewModel.currentHouseDetails?.id) { _, houseID in
                identityChanged(houseID, appViewModel.currentUserId)
            }
            .onChange(of: appViewModel.currentUserId) { _, userID in
                identityChanged(appViewModel.currentHouseDetails?.id, userID)
            }
            .onChange(of: appViewModel.isAuthenticated) { _, authenticated in
                if !authenticated { stop(); GameOrientationController.returnToPortrait() }
            }
            .onChange(of: requiresSignIn) { _, required in
                if required { stop(); appViewModel.logout(reason: .sessionRejected); GameOrientationController.returnToPortrait() }
            }
            .onDisappear {
                beforeStopOnDisappear()
                stop()
                GameOrientationController.returnToPortrait()
            }
    }
}

extension View {
    /// `requiresSignIn` is the model's "the server rejected this session" flag; the screen
    /// logs out when it turns on. `beforeStopOnDisappear` resets screen-local state.
    func onlineGameLifecycle(
        requiresSignIn: Bool,
        identityChanged: @escaping (_ houseID: String?, _ userID: String?) -> Void,
        stop: @escaping () -> Void,
        beforeStopOnDisappear: @escaping () -> Void = {}
    ) -> some View {
        modifier(OnlineGameLifecycle(
            requiresSignIn: requiresSignIn,
            identityChanged: identityChanged,
            stop: stop,
            beforeStopOnDisappear: beforeStopOnDisappear
        ))
    }
}
