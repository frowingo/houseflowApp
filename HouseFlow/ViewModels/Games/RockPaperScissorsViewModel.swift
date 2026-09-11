import Foundation
import Combine

@MainActor
final class RockPaperScissorsViewModel: ObservableObject {
    @Published var players = ["Sen", "Atlas", "Ada", "Ege"].enumerated().map {
        RPSPlayer(name: $0.element, avatarIndex: $0.offset)
    }
    @Published var newPlayerName = ""
    @Published private(set) var snapshot: RPSSnapshot?
    @Published private(set) var isSending = false
    @Published var errorKey: String?
    private let service: any RPSGameServicing

    init(service: any RPSGameServicing) { self.service = service }

    var canAddPlayer: Bool {
        let name = newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return players.count < 8 && !name.isEmpty && name.count <= 24 &&
            !players.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    func addPlayer() {
        guard canAddPlayer else { return }
        let avatar = (0..<8).first { candidate in !players.contains { $0.avatarIndex == candidate } } ?? 0
        players.append(RPSPlayer(name: newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines), avatarIndex: avatar))
        newPlayerName = ""
    }

    func removePlayer(_ player: RPSPlayer) {
        guard players.count > 2, player.id != players.first?.id else { return }
        players.removeAll { $0.id == player.id }
    }

    func observe() async {
        for await state in service.events() {
            guard !Task.isCancelled else { return }
            if let previous = snapshot, previous.sessionID == state.sessionID,
               previous.revision >= state.revision { continue }
            snapshot = state
        }
    }

    func start() async {
        guard !isSending, let localID = players.first?.id else { return }
        isSending = true
        defer { isSending = false }
        do { try await service.start(players: players, localPlayerID: localID) }
        catch { errorKey = "rps_error" }
    }

    func advance() async { await send(.advance) }

    func play(_ move: RPSMove?) async {
        guard let match = snapshot?.activeMatch else { return }
        await send(.play(matchID: match.id, attempt: match.attempt, move: move))
    }

    private func send(_ action: RPSAction) async {
        guard !isSending, let snapshot else { return }
        isSending = true
        defer { isSending = false }
        do {
            try await service.send(RPSCommand(sessionID: snapshot.sessionID, expectedRevision: snapshot.revision, action: action))
        } catch { errorKey = "rps_error" }
    }

    func stop() {
        service.disconnect()
        snapshot = nil
        errorKey = nil
    }
}
