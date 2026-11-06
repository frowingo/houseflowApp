import FausCrewCore
import SwiftUI
import UIKit

/// The Faus Switch palette. The course is a light textured sheet; robots, blocks and
/// rails are dark so they read at a glance. `wine` and `deepWine` carry the accents
/// next to teal and lavender so green never dominates; `berry` stays for lasers and
/// warnings. Panels are sand, fading to a lighter sand.
enum FausSwitchPalette {
    static let mint = Color(hex: "D8FDD4")
    static let lime = Color(hex: "D5E8A0")
    static let sand = Color(hex: "E6D5B7")
    static let lavender = Color(hex: "B6A0CF")
    static let green = Color(hex: "3D896D")
    static let teal = Color(hex: "164F52")
    static let plum = Color(hex: "30021F")
    static let berry = Color(hex: "7A2453")
    static let wine = Color(hex: "692747")
    static let deepWine = Color(hex: "501536")
    /// Sand mixed halfway toward white: the light end of the panel gradient.
    static let lightSand = Color(hex: "F3EBDD")

    static let ink = plum
    static let secondaryInk = deepWine.opacity(0.78)
    static let panel = lightSand.opacity(0.96)
    static let panelStroke = wine.opacity(0.18)
    static let danger = berry
    /// Accent for section titles, links and the primary action.
    static let accent = wine
    /// Every card and panel: light sand at the top fading to sand.
    static let cardFill = LinearGradient(colors: [lightSand, sand], startPoint: .topLeading, endPoint: .bottomTrailing)

    enum UI {
        static let mint = UIColor(fausHex: 0xD8FDD4)
        static let lime = UIColor(fausHex: 0xD5E8A0)
        static let sand = UIColor(fausHex: 0xE6D5B7)
        static let lavender = UIColor(fausHex: 0xB6A0CF)
        static let green = UIColor(fausHex: 0x3D896D)
        static let teal = UIColor(fausHex: 0x164F52)
        static let plum = UIColor(fausHex: 0x30021F)
        static let berry = UIColor(fausHex: 0x7A2453)
        static let wine = UIColor(fausHex: 0x692747)
        static let deepWine = UIColor(fausHex: 0x501536)
        /// The robot visor: the darkest teal, so the white eyes carry the face.
        static let visor = UIColor(fausHex: 0x0E2A2C)
    }
}

extension UIColor {
    /// Mixed toward black by `amount` (0…1): the robot's limbs and outlines.
    func switchDarkened(_ amount: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let keep = 1 - amount
        return UIColor(red: red * keep, green: green * keep, blue: blue * keep, alpha: alpha)
    }

    /// Mixed toward white by `amount` (0…1): head highlights.
    func switchLightened(_ amount: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(red: red + (1 - red) * amount, green: green + (1 - green) * amount,
                       blue: blue + (1 - blue) * amount, alpha: alpha)
    }
}

extension FausSwitchColor {
    var uiColor: UIColor { UIColor(fausHex: bodyHex) }
    var color: Color { Color(uiColor: uiColor) }
}

/// Whether the house's catalog lists Faus Switch; unknown until the first read.
enum FausSwitchOnlineCatalog: Equatable {
    case unknown
    case available(maximumPlayers: Int)
    case unavailable
}

/// One line of the result table.
struct FausSwitchStanding: Equatable, Identifiable {
    enum Status: Equatable {
        case running
        case finished
        case crashed(FausSwitchCrashReason?)
    }

    let id: String
    /// A localization key for bots, the server's display name for people.
    let nameKey: String?
    let displayName: String?
    let color: FausSwitchColor
    let rank: Int?
    let status: Status
    let isLocal: Bool
    var isConnected = true
    /// Seconds from the start for finishers.
    var time: Double?
}

/// A robot's name beside it on the start platform, shown until the countdown ends.
struct FausSwitchNameTag: Equatable, Identifiable {
    let id: String
    let nameKey: String?
    let displayName: String?
    let color: FausSwitchColor
    let isLocal: Bool
    /// The robot's center in track coordinates.
    let x: Double
    let y: Double
    /// The frame's camera focus (`FausSwitchRenderFrame.cameraFocus`).
    let cameraFocus: Double
}

/// What the overlays above the race show; equal values skip a SwiftUI redraw.
struct FausSwitchMatchUI: Equatable {
    var phase: FausSwitchMatchPhase = .countdown
    var countdown: Int?
    var standings: [FausSwitchStanding] = []
    /// Only during the countdown (robots stand still then).
    var nameTags: [FausSwitchNameTag] = []
    var localStatus: FausSwitchStanding.Status?
    var localRank: Int?
    var localTime: Double?
    var runnerCount = 0
    var canFlip = false
    /// Online: a banner key pair while the race is not live for this player.
    var noticeTitleKey: String?
    var noticeDetailKey: String?
    var noticeIsBlocking = false
    var canRetry = false
    var canReclaim = false
    /// Online: the persisted result replaces the race panel.
    var showsResult = false
    var showsRematchRoom = false

    static func standings(from frame: FausSwitchRenderFrame) -> [FausSwitchStanding] {
        frame.runners
            .map { runner in
                FausSwitchStanding(
                    id: runner.id, nameKey: runner.nameKey, displayName: runner.displayName, color: runner.color,
                    rank: runner.rank, status: status(of: runner.state), isLocal: runner.isLocal,
                    isConnected: runner.isConnected,
                    time: runner.state.finishedAtTick.map { FausSwitchMetrics.seconds($0) })
            }
            .sorted { ($0.rank ?? .max, $0.id) < ($1.rank ?? .max, $1.id) }
    }

    static func nameTags(from frame: FausSwitchRenderFrame) -> [FausSwitchNameTag] {
        guard frame.phase == .countdown else { return [] }
        return frame.runners.map {
            FausSwitchNameTag(id: $0.id, nameKey: $0.nameKey, displayName: $0.displayName, color: $0.color,
                              isLocal: $0.isLocal, x: $0.state.x, y: $0.state.y, cameraFocus: frame.cameraFocus)
        }
    }

    static func status(of state: FausSwitchRunnerState) -> FausSwitchStanding.Status {
        switch state.status {
        case .running: .running
        case .finished: .finished
        case .crashed: .crashed(state.crashReason)
        }
    }
}
