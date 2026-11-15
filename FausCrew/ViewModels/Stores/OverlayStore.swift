import Foundation
import Combine

@MainActor
final class OverlayStore: ObservableObject {
    @Published private(set) var isPresented = false

    func setPresented(_ isPresented: Bool) {
        guard self.isPresented != isPresented else { return }
        self.isPresented = isPresented
    }
}
