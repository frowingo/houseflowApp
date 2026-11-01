import Foundation
import Combine

@MainActor
final class OverlayStore: ObservableObject {
    @Published var isPresented = false
}
