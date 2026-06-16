import SwiftUI

// MARK: - Phase
private enum LuckySpinPhase: Equatable {
    case setup
    case spinning
    case result
}

// MARK: - Lucky Spin View
struct LuckySpinView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var members: [String] = ["Ali", "Ayse", "Mehmet", "Fatma"]
    @State private var newMemberName = ""
    @State private var showAddField = false
    @State private var phase: LuckySpinPhase = .setup
    @State private var wheelRotation: Double = 0
    @State private var resultIndex: Int? = nil
    @State private var spinTask: Task<Void, Never>?
    @State private var resultAppeared = false

    var body: some View {
        ZStack {
            AppDesign.Colors.background.ignoresSafeArea()
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
        .navigationBarBackButtonHidden(phase != .setup)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { spinTask?.cancel() }
    }

    // MARK: - Setup
    private var setupView: some View {
        VStack(spacing: 0) {
            spinSetupHeader
            LuckySpinMemberList(
                members: $members,
                newMemberName: $newMemberName,
                showAddField: $showAddField,
                onAddMember: addMember
            )
            Spacer(minLength: AppDesign.Spacing.lg)
            spinButton
        }
    }

    private var spinSetupHeader: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.1)).frame(width: 80, height: 80)
                Image(systemName: "arrow.2.circlepath")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Color.orange)
            }
            Text("Lucky Spin")
                .font(AppDesign.Typography.title2)
                .foregroundStyle(AppDesign.Colors.textPrimary)
            Text("Add members, spin, and let fate decide!")
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppDesign.Spacing.xxl)
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xl)
    }

    private var spinButton: some View {
        Button { startSpin() } label: {
            Label("Spin the Wheel", systemImage: "arrow.2.circlepath")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightLarge)
                .background(members.count >= 2 ? Color.orange : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        }
        .disabled(members.count < 2)
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.bottom, AppDesign.Spacing.xxxl)
    }

    // MARK: - Spinning
    private var spinningView: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            Spacer()

            Text("Spinning...")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.textSecondary)

            // Wheel + pointer
            ZStack(alignment: .top) {
                SpinWheelView(members: members, rotation: wheelRotation)
                    .frame(width: 288, height: 288)

                // Pointer pinned above center of wheel top
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.orange)
                    .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .offset(y: -20)
            }
            .frame(width: 288, height: 330)

            Spacer()
        }
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
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.append(trimmed)
            newMemberName = ""
            showAddField = false
        }
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

            // Center white cap
            Circle()
                .fill(Color.white)
                .frame(width: 46, height: 46)
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)

            // Orange center dot
            Circle()
                .fill(Color.orange)
                .frame(width: 20, height: 20)
        }
    }
}

// MARK: - Wheel Canvas
private struct WheelCanvas: View {
    let members: [String]

    private let segmentColors: [Color] = [
        Color(hue: 0.08, saturation: 0.80, brightness: 0.92),  // orange
        Color(hue: 0.58, saturation: 0.65, brightness: 0.80),  // blue
        Color(hue: 0.36, saturation: 0.58, brightness: 0.70),  // green
        Color(hue: 0.75, saturation: 0.52, brightness: 0.78),  // purple
        Color(hue: 0.97, saturation: 0.68, brightness: 0.84),  // red
        Color(hue: 0.14, saturation: 0.78, brightness: 0.90),  // yellow
    ]

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
                let color  = segmentColors[i % segmentColors.count]

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
            ctx.stroke(ring, with: .color(.white.opacity(0.7)), lineWidth: 3.5)
        }
    }
}

// MARK: - Lucky Spin Member List
private struct LuckySpinMemberList: View {
    @Binding var members: [String]
    @Binding var newMemberName: String
    @Binding var showAddField: Bool
    let onAddMember: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(members.indices, id: \.self) { index in
                MemberListRow(name: members[index], color: .orange, canDelete: members.count > 2) {
                    deleteMember(at: index)
                }
            }
            addMemberControl
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showAddField)
    }

    private func deleteMember(at index: Int) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.remove(at: index)
        }
    }

    @ViewBuilder
    private var addMemberControl: some View {
        if showAddField {
            HStack(spacing: AppDesign.Spacing.md) {
                TextField("Enter name...", text: $newMemberName)
                    .font(AppDesign.Typography.body)
                    .padding(AppDesign.Spacing.md)
                    .background(AppDesign.Colors.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    .onSubmit { onAddMember() }
                Button { onAddMember() } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.orange)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showAddField = true }
            } label: {
                Label("Add Member", systemImage: "plus.circle")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(Color.orange)
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.Spacing.md)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Lucky Spin Result Content
private struct LuckySpinResultContent: View {
    let winner: String
    @Binding var resultAppeared: Bool
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxxl) {
            Spacer()
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 110, height: 110)
                Text("🎯").font(.system(size: 58))
            }
            .scaleEffect(resultAppeared ? 1 : 0.2)
            .animation(.spring(response: 0.55, dampingFraction: 0.48).delay(0.05), value: resultAppeared)

            VStack(spacing: AppDesign.Spacing.sm) {
                Text("Selected:")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                Text(winner)
                    .font(.system(size: 42, weight: .black))
                    .foregroundStyle(Color.orange)
                Text("This person does the chore 🧹")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
            }
            .opacity(resultAppeared ? 1 : 0)
            .offset(y: resultAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: resultAppeared)

            Spacer()

            VStack(spacing: AppDesign.Spacing.md) {
                Button { onRetry() } label: {
                    Label("Spin Again", systemImage: "arrow.clockwise")
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightLarge)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { onDismiss() } label: {
                    Text("Main Menu")
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
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

// MARK: - Member List Row (shared with HotPotatoView)
struct MemberListRow: View {
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
                .foregroundStyle(AppDesign.Colors.textPrimary)
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
        .background(AppDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
}
