import Foundation

// The online lobby is shared by every realtime game; House Rockets keeps its names.
public typealias HouseRocketsOnlineLobbyState = GameOnlineLobbyState<HouseRocketsRealtime>
public typealias HouseRocketsPendingLobbyCommand = GamePendingLobbyCommand<HouseRocketsRealtime>
public typealias HouseRocketsOnlineLobbyIssue = GameOnlineLobbyIssue
public typealias HouseRocketsServerClock = GameServerClock
public typealias HouseRocketsOnlineEffect = GameOnlineEffect
public typealias HouseRocketsOnlineHaptic = GameOnlineHaptic
typealias HouseRocketsOnlineLobbyMachine = GameOnlineLobbyMachine<HouseRocketsRealtime>
typealias HouseRocketsOnlineResultMachine = GameOnlineResultMachine<HouseRocketsRealtime>
