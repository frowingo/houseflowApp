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
