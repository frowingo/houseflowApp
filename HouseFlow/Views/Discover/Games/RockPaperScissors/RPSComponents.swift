import SwiftUI

enum RPSTheme {
    static let ink = Color(hex: "091321")
    static let mint = Color(hex: "74F0CE")
    static let coral = Color(hex: "FF947F")
    static let lavender = Color(hex: "B8A3FF")
    static let secondary = Color(hex: "AAB9CD")
    static let colors: [Color] = [mint, coral, lavender, .cyan, .yellow, .pink, .orange, .blue]
    static let avatars = ["⚡️", "🪐", "🌊", "🔥", "🍀", "🌙", "🦊", "💎"]

    static func color(_ player: RPSPlayer) -> Color { colors[abs(player.avatarIndex % colors.count)] }
    static func avatar(_ player: RPSPlayer) -> String { avatars[abs(player.avatarIndex % avatars.count)] }
}

extension RPSMove {
    var emoji: String {
        switch self {
        case .rock: return "✊"
        case .paper: return "✋"
        case .scissors: return "✌️"
        }
    }
    var titleKey: String { "rps_\(rawValue)" }
}

struct RPSBackground: View {
    var body: some View {
        RPSTheme.ink
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

struct RPSAvatar: View {
    let player: RPSPlayer
    var size: CGFloat = 42
    var body: some View {
        Text(RPSTheme.avatar(player))
            .font(.system(size: size * 0.48))
            .frame(width: size, height: size)
            .background(RPSTheme.color(player).opacity(0.13), in: RoundedRectangle(cornerRadius: size * 0.34))
            .accessibilityHidden(true)
    }
}

struct RPSPrimaryButton: View {
    let key: String
    var icon = "arrow.right"
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                LocalizedText(key).font(.system(.headline, design: .rounded))
                Image(systemName: icon).font(.headline)
            }
            .foregroundStyle(RPSTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background(RPSTheme.mint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }
}

struct RPSHand: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let move: RPSMove?
    var color: Color = RPSTheme.mint
    var countdown: Int?
    var mirrored = false
    var winner = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.08))
            if winner {
                Circle().stroke(RPSTheme.mint, lineWidth: 2)
            }
            Text(move?.emoji ?? "✊")
                .font(.system(size: 62))
                .scaleEffect(x: mirrored ? -1 : 1, y: 1)
                .rotationEffect(.degrees(reduceMotion || countdown == nil ? 0 : (countdown!.isMultiple(of: 2) ? -18 : 18)))
                .offset(y: reduceMotion || countdown == nil ? 0 : (countdown!.isMultiple(of: 2) ? -8 : 5))
                .id(move)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.5).combined(with: .opacity))
        }
        .frame(maxWidth: 150)
        .aspectRatio(1, contentMode: .fit)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.55), value: countdown)
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.6), value: move)
        .accessibilityHidden(true)
    }
}

struct RPSBracket: View {
    let snapshot: RPSSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(snapshot.rounds) { round in
                VStack(alignment: .leading, spacing: 10) {
                    LocalizedText("rps_round", replacements: ["number": "\(round.number)"])
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(RPSTheme.mint)
                    ForEach(round.matches) { match in
                        VStack(spacing: 8) {
                            bracketPlayer(match.first, winner: match.winnerID == match.first.id, move: match.firstMove)
                            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
                            bracketPlayer(match.second, winner: match.winnerID == match.second.id, move: match.secondMove)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(.white.opacity(match.id == snapshot.activeMatchID ? 0.06 : 0),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let bye = round.bye {
                        HStack {
                            RPSAvatar(player: bye, size: 28)
                            Text(bye.name).font(.subheadline.weight(.medium))
                            Spacer()
                            LocalizedText("rps_bye_short").font(.caption).foregroundStyle(RPSTheme.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private func bracketPlayer(_ player: RPSPlayer, winner: Bool, move: RPSMove?) -> some View {
        HStack(spacing: 8) {
            RPSAvatar(player: player, size: 28)
            Text(player.name).font(.subheadline.weight(winner ? .bold : .regular))
                .foregroundStyle(winner ? RPSTheme.mint : .white)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let move {
                LocalizedText(move.titleKey).font(.caption).foregroundStyle(RPSTheme.secondary)
                Text(move.emoji).accessibilityHidden(true)
            }
            if winner {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(RPSTheme.mint)
            }
        }
    }
}
