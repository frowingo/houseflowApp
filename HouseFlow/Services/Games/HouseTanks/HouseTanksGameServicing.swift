import Foundation

/// Demo and future online implementations expose the same command/snapshot edge.
/// The online implementation must treat the server as the hit and winner authority.
@MainActor
protocol HouseTanksGameServicing: AnyObject {
    var scene: HouseTanksScene { get }

    func events() -> AsyncStream<HouseTanksSnapshot>
    func start(configuration: HouseTanksMatchConfiguration) async
    func send(_ command: HouseTanksCommand) async
    func pause()
    func resume()
    func setReduceMotion(_ enabled: Bool)
    func disconnect()
}

