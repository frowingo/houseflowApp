import Foundation
import Combine

@MainActor
final class ToastStore: ObservableObject {
    @Published private(set) var message: String?
    @Published private(set) var isError = true

    private var dismissTask: Task<Void, Never>?

    func show(message: String, isError: Bool = true) {
        dismissTask?.cancel()
        self.message = message
        self.isError = isError

        dismissTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(4))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self?.message == message else { return }
                self?.clear()
            }
        }
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        message = nil
    }
}
