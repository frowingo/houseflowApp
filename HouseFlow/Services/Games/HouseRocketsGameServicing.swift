import Foundation

/// The demo owns simulation and outcomes locally. An online service can replace it
/// while keeping the view model's command/snapshot boundary unchanged.
@MainActor
protocol HouseRocketsGameServicing: AnyObject {
    var scene: HouseRocketsScene { get }

    func events() -> AsyncStream<HouseRocketsSnapshot>
    func start(configuration: HouseRocketsConfiguration) async
    func send(_ command: HouseRocketsCommand) async
    func pause()
    func resume()
    func setReduceMotion(_ enabled: Bool)
    func disconnect()
}
