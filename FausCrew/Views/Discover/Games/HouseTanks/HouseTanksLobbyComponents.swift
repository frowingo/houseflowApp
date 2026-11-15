import SwiftUI
import FausCrewCore

/// Lobby text lookup shared by the lobby views; a key without a translation shows as itself.
struct HouseTanksCopy {
    let appViewModel: AppViewModel

    init(_ appViewModel: AppViewModel) {
        self.appViewModel = appViewModel
    }

    func callAsFunction(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    func callAsFunction(_ key: String, replacements: [String: String]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

extension HouseTanksColor {
    var swatchColor: Color {
        Color(uiColor: uiColor)
    }

    var nameKey: String {
        switch self {
        case .plum: "house_tanks_color_plum"
        case .orange: "house_tanks_color_orange"
        case .blue: "house_tanks_color_blue"
        case .olive: "house_tanks_color_olive"
        case .mustard: "house_tanks_color_mustard"
        case .crimson: "house_tanks_color_crimson"
        case .sky: "house_tanks_color_sky"
        case .ivory: "house_tanks_color_ivory"
        }
    }
}

/// Numbered section title ("01 / Map") used across the lobby.
struct HouseTanksSectionHeader: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let code: String
    let key: String

    private var copy: HouseTanksCopy { HouseTanksCopy(appViewModel) }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
            Text(verbatim: "\(code) /")
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(HouseTanksFieldTheme.accent)
            Text(copy(key))
                .font(.title3.weight(.bold))
                .foregroundStyle(HouseTanksFieldTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy(key))
        .accessibilityAddTraits(.isHeader)
    }
}

/// The player's own tank in one color, as it will look on the arena. The online room marks
/// colors other players hold as taken and locks the choice while the player is ready.
struct HouseTanksColorSwatch: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: AppDesign.Spacing.sm), count: 4)

    let color: HouseTanksColor
    let isSelected: Bool
    var isTaken = false
    var isLocked = false
    let action: () -> Void

    private var copy: HouseTanksCopy { HouseTanksCopy(appViewModel) }
    private var colorName: String { copy(color.nameKey) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppDesign.Spacing.xs) {
                HouseTanksArenaTank(color: color)
                    .frame(width: 52, height: 52)
                Text(colorName)
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? HouseTanksFieldTheme.ink : HouseTanksFieldTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, AppDesign.Spacing.sm)
            .frame(maxWidth: .infinity)
            .background(isSelected ? HouseTanksMapPalette.paper : HouseTanksMapPalette.sand.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                    .stroke(isSelected ? color.swatchColor : HouseTanksFieldTheme.hairline, lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(color.swatchColor)
                        .padding(5)
                } else if isTaken {
                    Image(systemName: "person.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(HouseTanksMapPalette.paper)
                        .padding(4)
                        .background(HouseTanksFieldTheme.ink, in: Circle())
                        .padding(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isTaken || isLocked)
        .opacity(isTaken || (isLocked && !isSelected) ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isTaken ? colorName + ", " + copy("house_tanks_color_taken") : colorName)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
