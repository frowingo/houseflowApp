import Foundation

/// Local bot session boundary. Online join/ready operations will have their own
/// contract; bot configuration and local pause are not online start parameters.
@MainActor
protocol HouseRocketsGameServicing: AnyObject {
    func events() -> AsyncStream<HouseRocketsSnapshot>
    func start(configuration: HouseRocketsConfiguration) async
    func send(_ command: HouseRocketsCommand) async
    func pause()
    func resume()
    func disconnect()
}
