import SwiftUI

enum RPSTheme {
    static let ink = Color(hex: "183A36")
    static let felt = Color(hex: "214B45")
    static let paper = Color(hex: "F7EFD9")
    static let paperInk = Color(hex: "243B39")
    static let action = Color(hex: "E9B44C")
    static let coral = Color(hex: "D9684F")
    static let blue = Color(hex: "557A9E")
    static let secondary = Color(hex: "CAD9CE")
    static let border = paper.opacity(0.16)
    static let colors: [Color] = [coral, blue, Color(hex: "63845C"), action, Color(hex: "775D80"), Color(hex: "3F8078"), Color(hex: "A86442"), Color(hex: "536D89")]
    static let avatarSymbols = ["house.fill", "leaf.fill", "drop.fill", "flame.fill", "moon.fill", "bolt.fill", "star.fill", "diamond.fill"]

    static func color(_ player: RPSPlayer) -> Color { colors[abs(player.avatarIndex % colors.count)] }
    static func avatarSymbol(_ player: RPSPlayer) -> String { avatarSymbols[abs(player.avatarIndex % avatarSymbols.count)] }

    static func moveColor(_ move: RPSMove?) -> Color {
        switch move {
        case .rock: return action
        case .paper: return blue
        case .scissors: return coral
        case nil: return paperInk.opacity(0.46)
        }
    }
}

extension RPSMove {
    var titleKey: String { "rps_\(rawValue)" }

    var rotation: Double {
        switch self {
        case .rock: return -5
        case .paper: return 4
        case .scissors: return -8
        }
    }
}

struct RPSBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [RPSTheme.felt, RPSTheme.ink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 46, style: .continuous)
                .stroke(RPSTheme.paper.opacity(0.06), lineWidth: 18)
                .frame(width: 360, height: 520)
                .rotationEffect(.degrees(-9))
                .offset(x: 150, y: -230)

            HStack(spacing: 18) {
                ForEach(0..<5, id: \.self) { _ in
                    Circle()
                        .fill(RPSTheme.paper.opacity(0.055))
                        .frame(width: 18, height: 18)
                }
            }
            .rotationEffect(.degrees(12))
            .offset(x: -90, y: 300)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct RPSAvatar: View {
    let player: RPSPlayer
    var size: CGFloat = 42
    var body: some View {
        Image(systemName: RPSTheme.avatarSymbol(player))
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundStyle(RPSTheme.color(player))
            .frame(width: size, height: size)
            .background(RPSTheme.paper.opacity(0.96), in: RoundedRectangle(cornerRadius: size * 0.30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                    .stroke(RPSTheme.color(player).opacity(0.35), lineWidth: 1)
            }
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
            .foregroundStyle(RPSTheme.paperInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .background(RPSTheme.action, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }
}

struct RPSHand: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let move: RPSMove?
    var color: Color = RPSTheme.action
    var countdown: Int?
    var mirrored = false
    var winner = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(RPSTheme.paper)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(winner ? RPSTheme.action : color.opacity(0.38), lineWidth: winner ? 4 : 2)

            RPSMoveMark(move: move, color: RPSTheme.moveColor(move))
                .padding(28)
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

struct RPSMoveMark: View {
    let move: RPSMove?
    var color: Color

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                switch move {
                case .rock:
                    rock(in: side)
                case .paper:
                    paper(in: side)
                case .scissors:
                    Image(systemName: "scissors")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(color)
                        .padding(side * 0.08)
                case nil:
                    Image(systemName: "questionmark")
                        .font(.system(size: side * 0.58, weight: .black, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func rock(in side: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: side * 0.18, y: side * 0.70))
            path.addLine(to: CGPoint(x: side * 0.10, y: side * 0.43))
            path.addLine(to: CGPoint(x: side * 0.30, y: side * 0.16))
            path.addLine(to: CGPoint(x: side * 0.64, y: side * 0.10))
            path.addLine(to: CGPoint(x: side * 0.88, y: side * 0.34))
            path.addLine(to: CGPoint(x: side * 0.82, y: side * 0.72))
            path.addLine(to: CGPoint(x: side * 0.54, y: side * 0.90))
            path.addLine(to: CGPoint(x: side * 0.28, y: side * 0.86))
            path.closeSubpath()
        }
        .fill(color)
        .overlay {
            Path { path in
                path.move(to: CGPoint(x: side * 0.30, y: side * 0.40))
                path.addLine(to: CGPoint(x: side * 0.58, y: side * 0.26))
                path.addLine(to: CGPoint(x: side * 0.73, y: side * 0.48))
            }
            .stroke(RPSTheme.paper.opacity(0.55), style: StrokeStyle(lineWidth: max(2, side * 0.045), lineCap: .round, lineJoin: .round))
        }
    }

    private func paper(in side: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                .fill(color)
                .padding(side * 0.11)

            VStack(alignment: .leading, spacing: side * 0.09) {
                Capsule().frame(width: side * 0.42, height: max(2, side * 0.045))
                Capsule().frame(width: side * 0.54, height: max(2, side * 0.045))
                Capsule().frame(width: side * 0.34, height: max(2, side * 0.045))
            }
            .foregroundStyle(RPSTheme.paper.opacity(0.70))
        }
    }
}

struct RPSHeroMoveCard: View {
    let move: RPSMove

    var body: some View {
        RPSMoveMark(move: move, color: RPSTheme.moveColor(move))
            .padding(14)
            .frame(width: 74, height: 84)
            .background(RPSTheme.paper, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(RPSTheme.moveColor(move).opacity(0.34), lineWidth: 2)
            }
            .rotationEffect(.degrees(move.rotation))
            .shadow(color: Color.black.opacity(0.16), radius: 9, x: 0, y: 5)
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
                        .foregroundStyle(RPSTheme.action)
                    ForEach(round.matches) { match in
                        VStack(spacing: 8) {
                            bracketPlayer(match.first, winner: match.winnerID == match.first.id, move: match.firstMove)
                            Rectangle().fill(RPSTheme.paper.opacity(0.10)).frame(height: 1)
                            bracketPlayer(match.second, winner: match.winnerID == match.second.id, move: match.secondMove)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(RPSTheme.paper.opacity(match.id == snapshot.activeMatchID ? 0.07 : 0),
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    if let bye = round.bye {
                        HStack {
                            RPSAvatar(player: bye, size: 28)
                            Text(bye.name).font(.subheadline.weight(.medium))
                            Spacer()
                            LocalizedText("rps_table_bye_short").font(.caption).foregroundStyle(RPSTheme.secondary)
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
                .foregroundStyle(winner ? RPSTheme.action : RPSTheme.paper)
                .lineLimit(1)
            Spacer(minLength: 4)
            if let move {
                LocalizedText(move.titleKey).font(.caption).foregroundStyle(RPSTheme.secondary)
                RPSMoveMark(move: move, color: RPSTheme.moveColor(move))
                    .frame(width: 22, height: 22)
            }
            if winner {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(RPSTheme.action)
            }
        }
    }
}
