import SwiftUI

// MARK: - Lucky Spin Theme
private enum LuckySpinTheme {
    static let backgroundTop = Color(hex: "120A1F")
    static let backgroundBottom = Color(hex: "05070C")
    static let surface = Color.white.opacity(0.08)
    static let elevated = Color.white.opacity(0.12)
    static let border = Color.white.opacity(0.14)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.48)
    static let gold = Color(hex: "F59E0B")
    static let pink = Color(hex: "EC4899")
    static let playerColors: [Color] = [
        Color(hex: "F59E0B"),
        Color(hex: "06B6D4"),
        Color(hex: "8B5CF6"),
        Color(hex: "EC4899"),
        Color(hex: "22C55E"),
        Color(hex: "EF4444"),
    ]
}

// MARK: - Background
private struct LuckySpinBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LuckySpinTheme.backgroundTop,
                    Color(hex: "1A102C"),
                    LuckySpinTheme.backgroundBottom,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(LuckySpinTheme.gold.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 28)
                .offset(x: 150, y: -260)

            Circle()
                .fill(LuckySpinTheme.pink.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 26)
                .offset(x: -160, y: 260)
        }
    }
}

// MARK: - Badge
private struct LuckySpinBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [LuckySpinTheme.gold, LuckySpinTheme.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: LuckySpinTheme.gold.opacity(0.28), radius: 14, x: 0, y: 6)

            Circle()
                .stroke(Color.white.opacity(0.42), lineWidth: 3)
                .frame(width: size * 0.58, height: size * 0.58)

            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.72))
                    .frame(width: size * 0.18, height: 4)
                    .offset(x: size * 0.24)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: size * 0.34, weight: .black))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Rule Row
private struct LuckyRuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(LuckySpinTheme.textPrimary)
                Text(detail)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(LuckySpinTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Phase
private enum LuckySpinPhase: Equatable {
    case setup
    case spinning
    case result
}

// MARK: - Lucky Spin View
struct LuckySpinView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var members: [String] = ["Ali", "Ayse", "Mehmet", "Fatma"]
    @State private var newMemberName = ""
    @State private var didLoadDefaultMembers = false
    @State private var showAddField = false
    @State private var phase: LuckySpinPhase = .setup
    @State private var wheelRotation: Double = 0
    @State private var resultIndex: Int? = nil
    @State private var spinTask: Task<Void, Never>?
    @State private var resultAppeared = false

    var body: some View {
        ZStack {
            LuckySpinBackground()
                .ignoresSafeArea()

            switch phase {
            case .setup:
                setupView.transition(.opacity)
            case .spinning:
                spinningView.transition(.opacity)
            case .result:
                resultView.transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .environment(\.colorScheme, .dark)
        .navigationBarBackButtonHidden(phase != .setup)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadDefaultMembersIfNeeded() }
        .onDisappear { spinTask?.cancel() }
    }

    // MARK: - Setup
    private var setupView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    spinSetupHeader
                    spinRoomPanel
                    memberPanel
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.top, AppDesign.Spacing.xxl)
                .padding(.bottom, AppDesign.Spacing.xxl)
            }

            spinButton
        }
    }

    private var spinSetupHeader: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            LuckySpinBadge(size: 104)

            Text(appViewModel.localized("lucky_spin_title"))
                .font(AppDesign.Typography.title2)
                .foregroundStyle(LuckySpinTheme.textPrimary)
            Text(appViewModel.localized("lucky_spin_subtitle"))
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(LuckySpinTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var spinRoomPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Label(appViewModel.localized("lucky_spin_room_label"), systemImage: "sparkles")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(LuckySpinTheme.textPrimary)
                Spacer()
                Text(appViewModel.localized(
                    "lucky_spin_players_count_template",
                    replacements: ["count": "\(members.count)"]
                ))
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(LuckySpinTheme.gold)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background(LuckySpinTheme.gold.opacity(0.16))
                    .clipShape(Capsule())
            }

            VStack(spacing: AppDesign.Spacing.sm) {
                LuckyRuleRow(icon: "person.3.fill", color: .cyan, title: appViewModel.localized("lucky_spin_rule_add_room_title"), detail: appViewModel.localized("lucky_spin_rule_add_room_detail"))
                LuckyRuleRow(icon: "arrow.2.circlepath", color: LuckySpinTheme.gold, title: appViewModel.localized("lucky_spin_rule_one_spin_title"), detail: appViewModel.localized("lucky_spin_rule_one_spin_detail"))
                LuckyRuleRow(icon: "target", color: LuckySpinTheme.pink, title: appViewModel.localized("lucky_spin_rule_winner_title"), detail: appViewModel.localized("lucky_spin_rule_winner_detail"))
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(LuckySpinTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(LuckySpinTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var memberPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text(appViewModel.localized("lucky_spin_players_title"))
                .font(AppDesign.Typography.headline)
                .foregroundStyle(LuckySpinTheme.textPrimary)

            LuckySpinMemberList(
                members: $members,
                newMemberName: $newMemberName,
                showAddField: $showAddField,
                onAddMember: addMember
            )
        }
        .padding(AppDesign.Spacing.lg)
        .background(LuckySpinTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(LuckySpinTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var spinButton: some View {
        Button { startSpin() } label: {
            Label(appViewModel.localized("lucky_spin_button"), systemImage: "arrow.2.circlepath")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightLarge)
                .background(
                    LinearGradient(
                        colors: members.count >= 2
                            ? [LuckySpinTheme.gold, LuckySpinTheme.pink]
                            : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                .shadow(color: LuckySpinTheme.gold.opacity(members.count >= 2 ? 0.28 : 0), radius: 14, x: 0, y: 6)
        }
        .disabled(members.count < 2)
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.bottom, AppDesign.Spacing.xxxl)
    }

    // MARK: - Spinning
    private var spinningView: some View {
        VStack(spacing: AppDesign.Spacing.xl) {
            Spacer()

            VStack(spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("lucky_spin_spinning_title"))
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(LuckySpinTheme.textPrimary)
                Text(appViewModel.localized("lucky_spin_spinning_subtitle"))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(LuckySpinTheme.textSecondary)
            }

            // Wheel + pointer
            ZStack(alignment: .top) {
                SpinWheelView(members: members, rotation: wheelRotation)
                    .frame(width: 288, height: 288)

                // Pointer pinned above center of wheel top
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(LuckySpinTheme.gold)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .offset(y: -20)
            }
            .padding(AppDesign.Spacing.xl)
            .background(LuckySpinTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl)
                    .stroke(LuckySpinTheme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl))
            .frame(width: 288, height: 330)

            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
    }

    // MARK: - Result
    private var resultView: some View {
        let winner = resultIndex.map { members[$0] } ?? ""
        return LuckySpinResultContent(
            winner: winner,
            resultAppeared: $resultAppeared,
            onRetry: {
                resultAppeared = false
                withAnimation(.easeInOut(duration: 0.25)) { phase = .setup }
            },
            onDismiss: { dismiss() }
        )
        .onAppear { resultAppeared = true }
    }

    // MARK: - Logic
    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !members.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.append(trimmed)
            newMemberName = ""
            showAddField = false
        }
    }

    private func loadDefaultMembersIfNeeded() {
        guard !didLoadDefaultMembers else { return }
        didLoadDefaultMembers = true
        members = [
            appViewModel.localized("lucky_spin_default_member_ali"),
            appViewModel.localized("lucky_spin_default_member_ayse"),
            appViewModel.localized("lucky_spin_default_member_mehmet"),
            appViewModel.localized("lucky_spin_default_member_fatma")
        ]
    }

    private func startSpin() {
        let count = members.count
        guard count >= 2 else { return }

        let target = Int.random(in: 0 ..< count)
        let segmentAngle = 360.0 / Double(count)
        // Center of target segment (clockwise from top)
        let targetCenter = Double(target) * segmentAngle + segmentAngle / 2.0
        let currentMod = wheelRotation.truncatingRemainder(dividingBy: 360.0)
        let delta = (targetCenter - currentMod + 360.0).truncatingRemainder(dividingBy: 360.0)
        // 10-13 full rotations for a long, exciting spin
        let fullRotations = Double(Int.random(in: 10...13)) * 360.0
        let finalRotation = wheelRotation + fullRotations + delta

        resultIndex = target

        // Show spinning phase, then kick off the animated rotation
        withAnimation(.easeInOut(duration: 0.25)) { phase = .spinning }

        spinTask?.cancel()
        spinTask = Task {
            // Let the transition complete
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 7.5)) {
                    wheelRotation = finalRotation
                }
            }
            // Wait for animation + small buffer
            try? await Task.sleep(nanoseconds: 8_200_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { phase = .result }
            }
        }
    }
}

// MARK: - Spin Wheel View
private struct SpinWheelView: View {
    let members: [String]
    let rotation: Double

    var body: some View {
        ZStack {
            WheelCanvas(members: members)
                .rotationEffect(.degrees(rotation))
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)

            // Dark center cap
            Circle()
                .fill(Color(hex: "111827"))
                .frame(width: 46, height: 46)
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 2))
                .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 3)

            // Orange center dot
            Circle()
                .fill(LuckySpinTheme.gold)
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Wheel Canvas
private struct WheelCanvas: View {
    let members: [String]

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let center = CGPoint(x: cx, y: cy)
            let radius = min(cx, cy) - 2.0
            let count = members.count
            let segDeg = 360.0 / Double(count)

            for i in 0 ..< count {
                let startDeg = Double(i) * segDeg - 90.0
                let endDeg   = Double(i + 1) * segDeg - 90.0
                let startA = Angle(degrees: startDeg)
                let endA   = Angle(degrees: endDeg)
                let color  = LuckySpinTheme.playerColors[i % LuckySpinTheme.playerColors.count]

                // Filled segment
                var seg = Path()
                seg.move(to: center)
                seg.addArc(center: center, radius: radius,
                           startAngle: startA, endAngle: endA, clockwise: false)
                seg.closeSubpath()
                ctx.fill(seg, with: .color(color))

                // Divider line
                let startRad = startDeg * .pi / 180.0
                var div = Path()
                div.move(to: center)
                div.addLine(to: CGPoint(
                    x: cx + radius * cos(startRad),
                    y: cy + radius * sin(startRad)
                ))
                ctx.stroke(div, with: .color(.white.opacity(0.85)), lineWidth: 2.5)

                // Label
                let midDeg = startDeg + segDeg / 2.0
                let midRad = midDeg * .pi / 180.0
                let labelR = radius * 0.63
                let lx = cx + labelR * cos(midRad)
                let ly = cy + labelR * sin(midRad)
                let fontSize = max(9.0, min(13.0, 52.0 / Double(count)))
                let label = ctx.resolve(
                    Text(members[i])
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundColor(.white)
                )
                ctx.draw(label, at: CGPoint(x: lx, y: ly), anchor: .center)
            }

            // Outer ring
            var ring = Path()
            ring.addEllipse(in: CGRect(
                x: cx - radius, y: cy - radius,
                width: radius * 2, height: radius * 2
            ))
            ctx.stroke(ring, with: .color(.white.opacity(0.82)), lineWidth: 4)
        }
    }
}

// MARK: - Lucky Spin Member List
private struct LuckySpinMemberList: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @Binding var members: [String]
    @Binding var newMemberName: String
    @Binding var showAddField: Bool
    let onAddMember: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(members.indices, id: \.self) { index in
                MemberListRow(
                    name: members[index],
                    color: LuckySpinTheme.playerColors[index % LuckySpinTheme.playerColors.count],
                    canDelete: members.count > 2
                ) {
                    deleteMember(at: index)
                }
            }
            addMemberControl
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showAddField)
    }

    private func deleteMember(at index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            _ = members.remove(at: index)
        }
    }

    @ViewBuilder
    private var addMemberControl: some View {
        if showAddField {
            HStack(spacing: AppDesign.Spacing.md) {
                TextField(appViewModel.localized("common_enter_name_placeholder"), text: $newMemberName)
                    .font(AppDesign.Typography.body)
                    .foregroundStyle(LuckySpinTheme.textPrimary)
                    .padding(AppDesign.Spacing.md)
                    .background(LuckySpinTheme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(LuckySpinTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    .onSubmit { onAddMember() }
                Button { onAddMember() } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(LuckySpinTheme.gold)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddField = true }
            } label: {
                Label(appViewModel.localized("common_add_member"), systemImage: "plus.circle")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(LuckySpinTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.Spacing.md)
                    .background(LuckySpinTheme.gold.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(LuckySpinTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Lucky Spin Result Content
private struct LuckySpinResultContent: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let winner: String
    @Binding var resultAppeared: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxxl) {
            Spacer()
            ZStack {
                Circle().fill(LuckySpinTheme.gold.opacity(0.16)).frame(width: 118, height: 118)
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 2).frame(width: 118, height: 118)
                Image(systemName: "target")
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(LuckySpinTheme.gold)
            }
            .scaleEffect(resultAppeared ? 1 : 0.2)
            .animation(.spring(response: 0.55, dampingFraction: 0.48).delay(0.05), value: resultAppeared)

            VStack(spacing: AppDesign.Spacing.sm) {
                LocalizedText("lucky_spin_selected_label")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(LuckySpinTheme.textSecondary)
                Text(winner)
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(LuckySpinTheme.gold)
                LocalizedText("lucky_spin_result_message")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(LuckySpinTheme.textSecondary)
            }
            .opacity(resultAppeared ? 1 : 0)
            .offset(y: resultAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: resultAppeared)

            Spacer()

            VStack(spacing: AppDesign.Spacing.md) {
                Button { onRetry() } label: {
                    Label(appViewModel.localized("lucky_spin_again_button"), systemImage: "arrow.clockwise")
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightLarge)
                        .background(
                            LinearGradient(
                                colors: [LuckySpinTheme.gold, LuckySpinTheme.pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { onDismiss() } label: {
                    Text(appViewModel.localized("common_main_menu"))
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundStyle(LuckySpinTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeight)
                }
            }
            .opacity(resultAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.38), value: resultAppeared)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xxxl)
    }
}

// MARK: - Lucky Member Row
private struct MemberListRow: View {
    let name: String
    let color: Color
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle().fill(color.opacity(0.1)).frame(width: 36, height: 36)
                Text(String(name.prefix(2)).uppercased())
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(color)
            }
            Text(name)
                .font(AppDesign.Typography.bodyBold)
                .foregroundStyle(LuckySpinTheme.textPrimary)
            Spacer()
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red.opacity(0.7))
                }
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(LuckySpinTheme.elevated)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(LuckySpinTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
}
