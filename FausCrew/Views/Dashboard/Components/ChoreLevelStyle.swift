import SwiftUI
import FausCrewCore

/// Presentation of a chore's difficulty: symbol and level colour (Android `ChoreLevelUi`).
extension ChoreLevel {
    var iconName: String {
        switch self { case .easy: return "leaf.fill"; case .medium: return "flame.fill"; case .hard: return "bolt.fill" }
    }
    var color: Color {
        switch self {
        case .easy:   return HouseJourneyTheme.levelEasy
        case .medium: return HouseJourneyTheme.levelMedium
        case .hard:   return HouseJourneyTheme.levelHard
        }
    }
}
