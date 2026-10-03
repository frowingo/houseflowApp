import SwiftUI

// MARK: - Lucky Spin Theme
private enum LuckySpinTheme {
    static let backgroundTop = Color(hex: "F7EFDE")
    static let backgroundBottom = Color(hex: "DDE9E0")
    static let surface = Color(hex: "FFF9EF")
    static let elevated = Color(hex: "EFE4CF")
    static let border = Color(hex: "17373A").opacity(0.16)
    static let textPrimary = Color(hex: "17373A")
    static let textSecondary = Color(hex: "526B6B")
    static let textTertiary = Color(hex: "6F807D")
    static let action = Color(hex: "2F8178")
    static let accent = Color(hex: "D86549")
    static let sun = Color(hex: "D89A2B")
    static let playerColors: [Color] = [
        Color(hex: "26786F"),
        Color(hex: "B6533C"),
        Color(hex: "3F6791"),
        Color(hex: "A96E1D"),
        Color(hex: "735783"),
        Color(hex: "557A52"),
    ]
}

// MARK: - Background
private struct LuckySpinBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [LuckySpinTheme.backgroundTop, LuckySpinTheme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Color.white.opacity(0.34))
                .frame(width: 320, height: 210)
                .rotationEffect(.degrees(11))
                .offset(x: 158, y: -270)

            Circle()
                .stroke(LuckySpinTheme.action.opacity(0.11), lineWidth: 18)
                .frame(width: 230, height: 230)
                .offset(x: -155, y: 290)

            VStack(spacing: 18) {
                Capsule().frame(width: 160, height: 5)
                Capsule().frame(width: 112, height: 5)
                Capsule().frame(width: 138, height: 5)
            }
            .foregroundStyle(LuckySpinTheme.textPrimary.opacity(0.07))
            .rotationEffect(.degrees(-12))
            .offset(x: 125, y: 250)
        }
    }
}

// MARK: - Badge
private struct LuckySpinBadge: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(LuckySpinTheme.surface)
                .frame(width: size, height: size)
                .overlay {
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                        .stroke(LuckySpinTheme.border, lineWidth: 1)
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: LuckySpinTheme.textPrimary.opacity(0.12), radius: 16, x: 0, y: 8)

            Circle()
                .fill(LuckySpinTheme.sun)
                .frame(width: size * 0.62, height: size * 0.62)
                .overlay {
                    Circle().stroke(LuckySpinTheme.textPrimary.opacity(0.28), lineWidth: 2)
                }

            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(index.isMultiple(of: 2) ? LuckySpinTheme.action : LuckySpinTheme.accent)
                    .frame(width: size * 0.18, height: 4)
                    .offset(x: size * 0.27)
                    .rotationEffect(.degrees(Double(index) * 45))
            }

            Image(systemName: "arrow.2.circlepath")
                .font(.system(size: size * 0.30, weight: .black))
                .foregroundStyle(LuckySpinTheme.textPrimary)
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
    @State private var memberErrorKey: String?
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
        .environment(\.colorScheme, .light)
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

            Text(appViewModel.localized("lucky_spin_home_title"))
                .font(AppDesign.Typography.title2)
                .foregroundStyle(LuckySpinTheme.textPrimary)
            Text(appViewModel.localized("lucky_spin_home_subtitle"))
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(LuckySpinTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var spinRoomPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Label(appViewModel.localized("lucky_spin_home_guide_title"), systemImage: "house.fill")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(LuckySpinTheme.textPrimary)
                Spacer()
                Text(appViewModel.localized(
                    "lucky_spin_home_count",
                    replacements: ["count": "\(members.count)"]
                ))
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(LuckySpinTheme.action)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background(LuckySpinTheme.action.opacity(0.12))
                    .clipShape(Capsule())
            }

            VStack(spacing: AppDesign.Spacing.sm) {
                LuckyRuleRow(icon: "person.3.fill", color: LuckySpinTheme.action, title: appViewModel.localized("lucky_spin_home_rule_names_title"), detail: appViewModel.localized("lucky_spin_home_rule_names_detail"))
                LuckyRuleRow(icon: "arrowtriangle.down.fill", color: LuckySpinTheme.sun, title: appViewModel.localized("lucky_spin_home_rule_pointer_title"), detail: appViewModel.localized("lucky_spin_home_rule_pointer_detail"))
                LuckyRuleRow(icon: "checkmark.seal.fill", color: LuckySpinTheme.accent, title: appViewModel.localized("lucky_spin_home_rule_result_title"), detail: appViewModel.localized("lucky_spin_home_rule_result_detail"))
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
            Text(appViewModel.localized("lucky_spin_home_names_title"))
                .font(AppDesign.Typography.headline)
                .foregroundStyle(LuckySpinTheme.textPrimary)

            LuckySpinMemberList(
                members: $members,
                newMemberName: $newMemberName,
                memberErrorKey: $memberErrorKey,
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
            Label(appViewModel.localized("lucky_spin_home_spin_button"), systemImage: "arrow.2.circlepath")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightLarge)
                .background(members.count >= 2 ? LuckySpinTheme.action : LuckySpinTheme.textTertiary.opacity(0.42))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                .shadow(color: LuckySpinTheme.textPrimary.opacity(members.count >= 2 ? 0.14 : 0), radius: 12, x: 0, y: 6)
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
                Text(appViewModel.localized("lucky_spin_home_spinning_title"))
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(LuckySpinTheme.textPrimary)
                Text(appViewModel.localized("lucky_spin_home_spinning_detail"))
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
                    .foregroundStyle(LuckySpinTheme.accent)
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
        let trimmed = newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            memberErrorKey = "lucky_spin_home_name_empty_error"
            return
        }
        guard !members.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            memberErrorKey = "lucky_spin_home_name_duplicate_error"
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.append(trimmed)
            newMemberName = ""
            memberErrorKey = nil
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
        let finalRotation = LuckySpinWheelMath.finalRotation(
            currentRotation: wheelRotation,
            selectedIndex: target,
            segmentCount: count,
            fullRotations: Int.random(in: 5...7)
        )

        resultIndex = target

        // Show spinning phase, then kick off the animated rotation
        withAnimation(.easeInOut(duration: 0.25)) { phase = .spinning }

        spinTask?.cancel()
        spinTask = Task {
            // Let the transition complete
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 4.8)) {
                    wheelRotation = finalRotation
                }
            }
            try? await Task.sleep(nanoseconds: 5_250_000_000)
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
                .fill(LuckySpinTheme.textPrimary)
                .frame(width: 46, height: 46)
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 2))
                .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 3)

            Circle()
                .fill(LuckySpinTheme.sun)
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
    @Binding var memberErrorKey: String?
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
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("lucky_spin_home_new_name_label"))
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(LuckySpinTheme.textSecondary)

                HStack(spacing: AppDesign.Spacing.md) {
                    TextField(appViewModel.localized("common_enter_name_placeholder"), text: $newMemberName)
                        .font(AppDesign.Typography.body)
                        .foregroundStyle(LuckySpinTheme.textPrimary)
                        .padding(AppDesign.Spacing.md)
                        .background(LuckySpinTheme.elevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .stroke(memberErrorKey == nil ? LuckySpinTheme.border : LuckySpinTheme.accent, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                        .onSubmit { onAddMember() }
                        .onChange(of: newMemberName) { _, _ in memberErrorKey = nil }
                    Button { onAddMember() } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(LuckySpinTheme.action)
                    }
                    .accessibilityLabel(appViewModel.localized("common_add_member"))
                }

                if let memberErrorKey {
                    Text(appViewModel.localized(memberErrorKey))
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(LuckySpinTheme.accent)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddField = true }
            } label: {
                Label(appViewModel.localized("common_add_member"), systemImage: "plus.circle")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(LuckySpinTheme.action)
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.Spacing.md)
                    .background(LuckySpinTheme.action.opacity(0.11))
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
            VStack(spacing: AppDesign.Spacing.xl) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LuckySpinTheme.sun.opacity(0.18))
                        .frame(width: 92, height: 78)
                        .rotationEffect(.degrees(-5))

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(LuckySpinTheme.action)
                }

                VStack(spacing: AppDesign.Spacing.sm) {
                    Text(appViewModel.localized("lucky_spin_home_selected_label"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundStyle(LuckySpinTheme.textSecondary)
                    Text(winner)
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(LuckySpinTheme.textPrimary)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    Text(appViewModel.localized("lucky_spin_home_result_detail"))
                        .font(AppDesign.Typography.subheadline)
                        .foregroundStyle(LuckySpinTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AppDesign.Spacing.xxl)
            .frame(maxWidth: 430)
            .background(LuckySpinTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous)
                    .stroke(LuckySpinTheme.border, lineWidth: 1)
            }
            .shadow(color: LuckySpinTheme.textPrimary.opacity(0.12), radius: 18, x: 0, y: 9)
            .scaleEffect(resultAppeared ? 1 : 0.94)
            .opacity(resultAppeared ? 1 : 0)
            .offset(y: resultAppeared ? 0 : 18)
            .animation(.spring(response: 0.58, dampingFraction: 0.72).delay(0.08), value: resultAppeared)
            .accessibilityElement(children: .combine)

            Spacer()

            VStack(spacing: AppDesign.Spacing.md) {
                Button { onRetry() } label: {
                    Label(appViewModel.localized("lucky_spin_home_again_button"), systemImage: "arrow.clockwise")
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightLarge)
                        .background(LuckySpinTheme.action)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { onDismiss() } label: {
                    Text(appViewModel.localized("lucky_spin_home_exit_button"))
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
    @EnvironmentObject private var appViewModel: AppViewModel

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
                .accessibilityLabel(appViewModel.localized(
                    "lucky_spin_home_remove_name",
                    replacements: ["name": name]
                ))
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
